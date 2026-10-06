include { MINIMAP2_ALIGN                         } from '../../../modules/nf-core/minimap2/align/main'
include { SAMTOOLS_SORT                          } from '../../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_INDEX                         } from '../../../modules/nf-core/samtools/index/main'
include { METABAT2_JGISUMMARIZEBAMCONTIGDEPTHS   } from '../../../modules/nf-core/metabat2/jgisummarizebamcontigdepths/main'
include { METABAT2_METABAT2                      } from '../../../modules/nf-core/metabat2/metabat2/main'
include { CHECKM2_PREDICT                        } from '../../../modules/nf-core/checkm2/predict/main'
include { GTDBTK_CLASSIFYWF                      } from '../../../modules/nf-core/gtdbtk/classifywf/main'

workflow BINNING_QC_TAXONOMY {
    take:
    ch_reads     // channel: [ val(meta), path(reads) ]
    ch_contigs   // channel: [ val(meta), path(contigs) ]
    ch_checkm2_db// channel: [ val(meta), path(db) ] (optional)
    ch_gtdb_db   // channel: [ val(meta), path(db) ] (optional)

    main:
    ch_versions = channel.empty()
    ch_bins     = channel.empty()
    ch_checkm2  = channel.empty()
    ch_gtdb     = channel.empty()

    // 1. Map reads to contigs to determine coverage depth
    MINIMAP2_ALIGN (
        ch_reads,
        ch_contigs,
        true,
        'bai',
        false,
        false
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions_minimap2)

    SAMTOOLS_SORT (
        MINIMAP2_ALIGN.out.bam,
        [ [id:'contigs'], [], [] ],
        'bai'
    )
    ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions_samtools)

    SAMTOOLS_INDEX (
        SAMTOOLS_SORT.out.bam
    )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions_samtools)

    // 2. Generate contig depth table
    ch_sorted_bam_bai = SAMTOOLS_SORT.out.bam.join(SAMTOOLS_INDEX.out.index)
    METABAT2_JGISUMMARIZEBAMCONTIGDEPTHS (
        ch_sorted_bam_bai.map { meta, bam, bai -> [ meta, [bam], [bai] ] }
    )
    ch_versions = ch_versions.mix(METABAT2_JGISUMMARIZEBAMCONTIGDEPTHS.out.versions_metabat2)

    // 3. Run MetaBAT2 binning
    ch_metabat_in = ch_contigs.join(METABAT2_JGISUMMARIZEBAMCONTIGDEPTHS.out.depth)
    METABAT2_METABAT2 (
        ch_metabat_in
    )
    ch_versions = ch_versions.mix(METABAT2_METABAT2.out.versions_metabat2)

    // Fallback: If MetaBAT2 produces 0 bins (e.g. single isolate or unbinned contigs),
    // fall back to using the assembly contigs so CheckM2 and GTDB-Tk run for every sample.
    ch_bins_or_contigs = ch_contigs
        .join(METABAT2_METABAT2.out.fasta, remainder: true)
        .map { meta, contigs, bins ->
            def bins_in = bins ?: [contigs]
            [ meta, bins_in ]
        }

    // 4. CheckM2 completeness & contamination prediction
    if (ch_checkm2_db) {
        CHECKM2_PREDICT (
            ch_bins_or_contigs,
            ch_checkm2_db
        )
        ch_checkm2  = CHECKM2_PREDICT.out.checkm2_tsv
        ch_versions = ch_versions.mix(CHECKM2_PREDICT.out.versions_checkm2_predict)
    }

    // 5. GTDB-Tk taxonomic classification
    if (ch_gtdb_db) {
        GTDBTK_CLASSIFYWF (
            ch_bins_or_contigs,
            ch_gtdb_db,
            false
        )
        ch_gtdb     = GTDBTK_CLASSIFYWF.out.summary
        ch_versions = ch_versions.mix(GTDBTK_CLASSIFYWF.out.versions_gtdbtk)
    }

    emit:
    bins        = METABAT2_METABAT2.out.fasta
    checkm2_tsv = ch_checkm2
    gtdb_tsv    = ch_gtdb
    sorted_bam  = SAMTOOLS_SORT.out.bam
    sorted_bai  = SAMTOOLS_INDEX.out.index
    versions    = ch_versions
}
