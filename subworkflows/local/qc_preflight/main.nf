include { NANOPLOT } from '../../../modules/nf-core/nanoplot/main'

workflow QC_PREFLIGHT {
    take:
    ch_reads // channel: [ val(meta), path(reads) ]

    main:
    ch_versions = channel.empty()
    ch_reports  = channel.empty()

    NANOPLOT (
        ch_reads
    )
    ch_reports  = ch_reports.mix(NANOPLOT.out.html.map { _meta, report -> report })
    ch_versions = ch_versions.mix(NANOPLOT.out.versions_nanoplot)

    emit:
    reports  = ch_reports
    versions = ch_versions
}
