/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { STAGE_REFERENCES          } from '../subworkflows/local/stage_references'
include { QC_PREFLIGHT               } from '../subworkflows/local/qc_preflight'
include { BASECALL_AND_CLEAN         } from '../subworkflows/local/basecall_and_clean'
include { DECONTAMINATION            } from '../subworkflows/local/decontamination'
include { ASSEMBLY_AND_CLASSIFY      } from '../subworkflows/local/assembly_and_classify'
include { BINNING_QC_TAXONOMY        } from '../subworkflows/local/binning_qc_taxonomy'
include { METAEPIGENOMICS_ANNOTATION } from '../subworkflows/local/metaepigenomics_annotation'
include { MANIFEST_WRITER            } from '../modules/local/manifest_writer/main'
include { QUARTO_REPORT              } from '../modules/local/quarto/report/main'
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
    // SUBWORKFLOW 0: Stage References & Databases (Automatic resolution & optional download)
    //
    STAGE_REFERENCES (
        params.human_fasta,
        params.host_fasta,
        params.host,
        params.download_dbs ?: false,
        params.db_cache_dir,
        params.checkm2_db,
        params.amr_db,
        params.genomad_db,
        params.gtdb_db,
        params.bakta_db
    )
    ch_versions    = ch_versions.mix(STAGE_REFERENCES.out.versions)
    ch_human_ref   = STAGE_REFERENCES.out.human_ref
    ch_hosts_ref   = STAGE_REFERENCES.out.hosts_ref
    ch_checkm2_db  = STAGE_REFERENCES.out.checkm2_db
    ch_amr_db      = STAGE_REFERENCES.out.amr_db
    ch_genomad_db  = STAGE_REFERENCES.out.genomad_db
    ch_gtdb_db     = STAGE_REFERENCES.out.gtdb_db
    ch_bakta_db    = STAGE_REFERENCES.out.bakta_db

    //
    // SUBWORKFLOW 2: Basecalling & Read Cleaning (Dorado, Porechop_ABI, Filtlong)
    //
    BASECALL_AND_CLEAN (
        ch_samplesheet,
        params.skip_basecalling ?: false,
        params.dorado_model     ?: 'dna_r10.4.1_e8.2_400bps_sup@v4.3.0',
        params.dorado_modified_bases ?: (params.dorado_modbase ?: '4mC_5mC,6mA')
    )
    ch_versions = ch_versions.mix(BASECALL_AND_CLEAN.out.versions)

    //
    // SUBWORKFLOW 1: QC Preflight (NanoPlot on cleaned reads)
    //
    QC_PREFLIGHT (
        BASECALL_AND_CLEAN.out.reads
    )
    ch_versions = ch_versions.mix(QC_PREFLIGHT.out.versions)

    //
    // SUBWORKFLOW 3: Decontamination (Human screening + Food-host depletion + Mosdepth)
    //
    DECONTAMINATION (
        BASECALL_AND_CLEAN.out.reads,
        ch_human_ref,
        ch_hosts_ref
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
        BASECALL_AND_CLEAN.out.bam,
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
    ch_manifest_in = ASSEMBLY_AND_CLASSIFY.out.contigs
        .map { meta, _contigs -> [ meta ] }
        .combine(DECONTAMINATION.out.stats.map { _meta, f -> f }.toList())
        .combine(BINNING_QC_TAXONOMY.out.checkm2_tsv.map { _meta, f -> f }.ifEmpty([]).toList())
        .combine(METAEPIGENOMICS_ANNOTATION.out.amr_report.map { _meta, f -> f }.ifEmpty([]).toList())
        .combine(METAEPIGENOMICS_ANNOTATION.out.motifs.map { _meta, f -> f }.ifEmpty([]).toList())
        .map { row ->
            def meta        = row[0]
            def stats_files = row[1] instanceof List ? row[1] : (row[1] ? [row[1]] : [])
            def checkm2     = row[2] instanceof List ? (row[2] ? row[2][0] : []) : (row[2] ?: [])
            def amr         = row[3] instanceof List ? (row[3] ? row[3][0] : []) : (row[3] ?: [])
            def motifs      = row[4] instanceof List ? (row[4] ? row[4][0] : []) : (row[4] ?: [])
            [ meta, stats_files, checkm2, amr, motifs ]
        }

    MANIFEST_WRITER (
        ch_manifest_in,
        workflow.manifest.version ?: '1.0.0dev'
    )
    ch_versions = ch_versions.mix(MANIFEST_WRITER.out.versions_python)

    //
    // MODULE: Quarto Clinical & Analytical Report
    //
    ch_quarto_in = MANIFEST_WRITER.out.manifest_json
        .combine(BINNING_QC_TAXONOMY.out.checkm2_tsv.map { _meta, f -> f }.ifEmpty([]).toList())
        .combine(METAEPIGENOMICS_ANNOTATION.out.amr_report.map { _meta, f -> f }.ifEmpty([]).toList())
        .combine(METAEPIGENOMICS_ANNOTATION.out.virulence.map { _meta, f -> f }.ifEmpty([]).toList())
        .combine(METAEPIGENOMICS_ANNOTATION.out.motifs.map { _meta, f -> f }.ifEmpty([]).toList())
        .combine(BINNING_QC_TAXONOMY.out.gtdb_tsv.map { _meta, f -> f }.ifEmpty([]).toList())
        .combine(DECONTAMINATION.out.stats.map { _meta, f -> f }.toList())
        .map { row ->
            def meta        = row[0]
            def manifest    = row[1]
            def checkm2     = row[2] instanceof List ? (row[2] ? row[2][0] : []) : (row[2] ?: [])
            def amr         = row[3] instanceof List ? (row[3] ? row[3][0] : []) : (row[3] ?: [])
            def vir         = row[4] instanceof List ? (row[4] ? row[4][0] : []) : (row[4] ?: [])
            def motifs      = row[5] instanceof List ? (row[5] ? row[5][0] : []) : (row[5] ?: [])
            def gtdb        = row[6] instanceof List ? (row[6] ? row[6][0] : []) : (row[6] ?: [])
            def stats_files = row[7] instanceof List ? row[7] : (row[7] ? [row[7]] : [])
            [ meta, manifest, checkm2, amr, vir, motifs, gtdb, stats_files ]
        }

    QUARTO_REPORT (
        ch_quarto_in,
        file("${projectDir}/assets/report.qmd", checkIfExists: true),
        file("${projectDir}/assets/report_custom.css", checkIfExists: true)
    )
    ch_versions = ch_versions.mix(QUARTO_REPORT.out.versions_quarto)

    //
    // Collate software versions
    //
    def all_version_entries = ch_versions.mix(channel.topic("versions")).distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: entry instanceof List || entry instanceof Object[]
        }

    def topic_versions_string = all_version_entries.versions_tuple
        .map { tuple ->
            def process = tuple[0]
            def tool    = tuple[1]
            def version = tuple[2]
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(all_version_entries.versions_file)
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
    ch_multiqc_files = ch_multiqc_files.mix(QC_PREFLIGHT.out.txt.map { _meta, f -> f })
    ch_multiqc_files = ch_multiqc_files.mix(DECONTAMINATION.out.mosdepth_global.map { _meta, f -> f }.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(DECONTAMINATION.out.mosdepth_summary.map { _meta, f -> f }.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(BASECALL_AND_CLEAN.out.porechop_log.map { _meta, f -> f })
    ch_multiqc_files = ch_multiqc_files.mix(BASECALL_AND_CLEAN.out.filtlong_log.map { _meta, f -> f })
    ch_multiqc_files = ch_multiqc_files.mix(ASSEMBLY_AND_CLASSIFY.out.assembly_txt.map { _meta, f -> f })
    ch_multiqc_files = ch_multiqc_files.mix(ASSEMBLY_AND_CLASSIFY.out.assembly_log.map { _meta, f -> f })
    ch_multiqc_files = ch_multiqc_files.mix(BINNING_QC_TAXONOMY.out.checkm2_tsv.map { _meta, f -> f })
    ch_multiqc_files = ch_multiqc_files.mix(METAEPIGENOMICS_ANNOTATION.out.amr_report.map { _meta, f -> f })
    ch_multiqc_files = ch_multiqc_files.mix(METAEPIGENOMICS_ANNOTATION.out.virulence.map { _meta, f -> f })
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
    quarto_report  = QUARTO_REPORT.out.html.mix(QUARTO_REPORT.out.pdf).map { _meta, report -> [report] }.toList()
    versions       = ch_versions
}
