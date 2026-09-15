include { MINIMAP2_ALIGN as MAP_HUMAN } from '../../../modules/nf-core/minimap2/align/main'
include { MINIMAP2_ALIGN as MAP_HOST  } from '../../../modules/nf-core/minimap2/align/main'
include { DECONTAMINATION_FILTER_READS as FILTER_HUMAN } from '../../../modules/local/decontamination/filter_reads/main'
include { DECONTAMINATION_FILTER_READS as FILTER_HOST  } from '../../../modules/local/decontamination/filter_reads/main'
include { MOSDEPTH                    } from '../../../modules/nf-core/mosdepth/main'
include { SAMTOOLS_INDEX              } from '../../../modules/nf-core/samtools/index/main'

workflow DECONTAMINATION {
    take:
    ch_reads        // channel: [ val(meta), path(reads) ]
    ch_human_ref    // channel: [ val(meta_human), path(fasta) ] (optional)
    ch_host_ref     // channel: [ val(meta_host), path(fasta) ] (optional)

    main:
    ch_versions = channel.empty()
    ch_stats    = channel.empty()
    ch_clean_reads = ch_reads

    // Step 1: Human read screening & removal
    if (ch_human_ref) {
        MAP_HUMAN (
            ch_clean_reads,
            ch_human_ref,
            true, // bam_format
            'bai', // bam_index_extension
            false, // cigar_paf_format
            false  // cigar_bam
        )
        ch_versions = ch_versions.mix(MAP_HUMAN.out.versions_minimap2)

        FILTER_HUMAN (
            MAP_HUMAN.out.bam,
            'human'
        )
        ch_stats = ch_stats.mix(FILTER_HUMAN.out.stats)
        ch_versions = ch_versions.mix(FILTER_HUMAN.out.versions_samtools)
    }

    // Step 2: Food Host depletion (meat / leafy green)
    if (ch_host_ref) {
        MAP_HOST (
            ch_clean_reads,
            ch_host_ref,
            true,
            'bai',
            false,
            false
        )
        ch_versions = ch_versions.mix(MAP_HOST.out.versions_minimap2)

        FILTER_HOST (
            MAP_HOST.out.bam,
            'host'
        )
        ch_stats = ch_stats.mix(FILTER_HOST.out.stats)
        ch_versions = ch_versions.mix(FILTER_HOST.out.versions_samtools)

        // Post-decontamination depth & ratio QC
        SAMTOOLS_INDEX (
            FILTER_HOST.out.bam
        )
        ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions_samtools)

        ch_bam_bai = FILTER_HOST.out.bam.join(SAMTOOLS_INDEX.out.index)
        MOSDEPTH (
            ch_bam_bai.map { meta, bam, bai -> [ meta, bam, bai, [] ] },
            [ [id:'host'], [] ],
            []
        )
        ch_versions = ch_versions.mix(MOSDEPTH.out.versions_mosdepth)
    }

    emit:
    clean_reads = ch_clean_reads
    stats       = ch_stats
    versions    = ch_versions
}
