include { DORADO_BASECALL } from '../../../modules/local/dorado/basecall/main'
include { PORECHOP_ABI    } from '../../../modules/nf-core/porechop/abi/main'
include { FILTLONG        } from '../../../modules/nf-core/filtlong/main'

workflow BASECALL_AND_CLEAN {
    take:
    ch_inputs          // channel: [ val(meta), path(input_file) ]
    val_skip_basecall  // boolean
    val_dorado_model   // string
    val_dorado_modbase // string

    main:
    ch_versions = channel.empty()
    ch_reads    = channel.empty()
    ch_bam      = channel.empty()

    if (!val_skip_basecall) {
        DORADO_BASECALL (
            ch_inputs,
            val_dorado_model,
            val_dorado_modbase
        )
        ch_bam      = DORADO_BASECALL.out.bam
        ch_versions = ch_versions.mix(DORADO_BASECALL.out.versions_dorado)
    } else {
        ch_bam = ch_inputs
    }

    // Porechop adapter & chimera trimming
    PORECHOP_ABI (
        ch_inputs,
        []
    )
    ch_versions = ch_versions.mix(PORECHOP_ABI.out.versions_porechop_abi)

    // Filtlong length and quality filtering
    FILTLONG (
        PORECHOP_ABI.out.reads.map { meta, reads -> [ meta, [], reads ] }
    )
    ch_reads    = FILTLONG.out.reads
    ch_versions = ch_versions.mix(FILTLONG.out.versions_filtlong)

    emit:
    reads    = ch_reads
    bam      = ch_bam
    versions = ch_versions
}
