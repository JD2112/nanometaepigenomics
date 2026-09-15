/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { QC_PREFLIGHT               } from '../subworkflows/local/qc_preflight'
include { BASECALL_AND_CLEAN         } from '../subworkflows/local/basecall_and_clean'
include { DECONTAMINATION            } from '../subworkflows/local/decontamination'
include { ASSEMBLY_AND_CLASSIFY      } from '../subworkflows/local/assembly_and_classify'
include { BINNING_QC_TAXONOMY        } from '../subworkflows/local/binning_qc_taxonomy'
include { METAEPIGENOMICS_ANNOTATION } from '../subworkflows/local/metaepigenomics_annotation'
include { MANIFEST_WRITER            } from '../modules/local/manifest_writer/main'
include { MULTIQC                    } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap           } from 'plugin/nf-schema'
include { paramsSummaryMultiqc       } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML     } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText     } from '../subworkflows/local/utils_nfcore_nanometaepigenomics_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow NANOMETAEPIGENOMICS {

    take:
    ch_samplesheet // channel: [ val(meta), path(reads_or_inputs) ]
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:
    def ch_versions      = channel.empty()
    def ch_multiqc_files = channel.empty()

    //
    // Optional Reference / DB Channels
    //
    ch_human_ref   = params.human_fasta ? channel.fromPath(params.human_fasta).map { [ [id:'human'], it ] } : null
    ch_host_ref    = params.host_fasta  ? channel.fromPath(params.host_fasta).map  { [ [id:'host'], it ] }  : null
    ch_genomad_db  = params.genomad_db  ? channel.fromPath(params.genomad_db).map  { [ [id:'genomad'], it ] } : null
    ch_checkm2_db  = params.checkm2_db  ? channel.fromPath(params.checkm2_db).map  { [ [id:'checkm2'], it ] } : null
    ch_gtdb_db     = params.gtdb_db     ? channel.fromPath(params.gtdb_db).map     { [ [id:'gtdb'], it ] }    : null
    ch_amr_db      = params.amr_db      ? channel.fromPath(params.amr_db).map      { [ [id:'amr'], it ] }     : null
    ch_bakta_db    = params.bakta_db    ? channel.fromPath(params.bakta_db).map    { [ [id:'bakta'], it ] }   : null

    //
    // SUBWORKFLOW 1: QC Preflight (NanoPlot on raw inputs)
    //
    QC_PREFLIGHT (
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(QC_PREFLIGHT.out.versions)

    //
    // SUBWORKFLOW 2: Basecalling & Read Cleaning (Dorado, Porechop_ABI, Filtlong)
    //
    BASECALL_AND_CLEAN (
        ch_samplesheet,
        params.skip_basecalling ?: false,
        params.dorado_model     ?: 'dna_r10.4.1_e8.2_400bps_sup@v4.3.0',
        params.dorado_modbase   ?: '5mCG_5hmCG'
    )
    ch_versions = ch_versions.mix(BASECALL_AND_CLEAN.out.versions)

    //
    // SUBWORKFLOW 3: Decontamination (Human screening + Food-host depletion + Mosdepth)
    //
    DECONTAMINATION (
        BASECALL_AND_CLEAN.out.reads,
        ch_human_ref,
        ch_host_ref
    )
    ch_versions = ch_versions.mix(DECONTAMINATION.out.versions)

    //
    // SUBWORKFLOW 4: Assembly & Sequence Classification (Flye + geNomad)
    //
    ASSEMBLY_AND_CLASSIFY (
        DECONTAMINATION.out.clean_reads,
        params.flye_mode ?: '--nano-hq',
        ch_genomad_db
    )
    ch_versions = ch_versions.mix(ASSEMBLY_AND_CLASSIFY.out.versions)

    //
    // SUBWORKFLOW 5: Binning, QC & Taxonomy (MetaBAT2, CheckM2, GTDB-Tk)
    //
    BINNING_QC_TAXONOMY (
        DECONTAMINATION.out.clean_reads,
        ASSEMBLY_AND_CLASSIFY.out.contigs,
        ch_checkm2_db,
        ch_gtdb_db
    )
    ch_versions = ch_versions.mix(BINNING_QC_TAXONOMY.out.versions)

    //
    // SUBWORKFLOW 6: Epigenomics & Annotation (Modkit, Nanomotif, AMRFinderPlus, Abricate, PlasmidFinder, Bakta)
    //
    ch_bam_bai_for_modkit = BINNING_QC_TAXONOMY.out.sorted_bam.join(BINNING_QC_TAXONOMY.out.sorted_bai)
    METAEPIGENOMICS_ANNOTATION (
        ch_bam_bai_for_modkit,
        ASSEMBLY_AND_CLASSIFY.out.contigs,
        BINNING_QC_TAXONOMY.out.bins,
        ch_amr_db,
        ch_bakta_db
    )
    ch_versions = ch_versions.mix(METAEPIGENOMICS_ANNOTATION.out.versions)

    //
    // MODULE: Manifest & Clinical Summary Writer
    //
    ch_manifest_in = DECONTAMINATION.out.stats
        .join(BINNING_QC_TAXONOMY.out.checkm2_tsv, remainder: true)
        .join(METAEPIGENOMICS_ANNOTATION.out.amr_report, remainder: true)
        .join(METAEPIGENOMICS_ANNOTATION.out.motifs, remainder: true)
        .map { meta, stats, checkm2, amr, motifs ->
            [ meta, stats ?: [], checkm2 ?: [], amr ?: [], motifs ?: [] ]
        }

    MANIFEST_WRITER (
        ch_manifest_in,
        workflow.manifest.version ?: '1.0.0dev'
    )
    ch_versions = ch_versions.mix(MANIFEST_WRITER.out.versions_python)

    //
    // Collate software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_nanometaepigenomics_software_mqc_versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MultiQC Reporting
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))

    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'nanometaepigenomics'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )

    emit:
    multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList()
    versions       = ch_versions
}
