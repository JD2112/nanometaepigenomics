include { NANOPLOT } from '../../../modules/nf-core/nanoplot/main'

workflow QC_PREFLIGHT {
    take:
    ch_reads // channel: [ val(meta), path(reads) ]

    main:
    ch_versions = channel.empty()
    ch_reports  = channel.empty()

    ch_valid_reads = ch_reads.filter { meta, file ->
        def f = file.toString()
        f.endsWith('.fastq.gz') || f.endsWith('.fq.gz') || f.endsWith('.fastq') || f.endsWith('.bam') || f.endsWith('.txt') || !f.endsWith('.pod5')
    }

    NANOPLOT (
        ch_valid_reads
    )
    ch_reports  = ch_reports.mix(NANOPLOT.out.html.map { _meta, report -> report })
    ch_versions = ch_versions.mix(NANOPLOT.out.versions_nanoplot)

    emit:
    html     = NANOPLOT.out.html
    reports  = ch_reports
    txt      = NANOPLOT.out.txt
    versions = ch_versions
}
