include { FLYE            } from '../../../modules/nf-core/flye/main'
include { GENOMAD_ENDTOEND } from '../../../modules/nf-core/genomad/endtoend/main'

workflow ASSEMBLY_AND_CLASSIFY {
    take:
    ch_reads      // channel: [ val(meta), path(reads) ]
    val_flye_mode // string (e.g. '--nano-hq')
    ch_genomad_db // channel: [ val(meta), path(db) ] (optional)

    main:
    ch_versions = channel.empty()
    ch_contigs  = channel.empty()
    ch_plasmids = channel.empty()

    FLYE (
        ch_reads,
        val_flye_mode
    )
    ch_contigs  = FLYE.out.fasta
    ch_versions = ch_versions.mix(FLYE.out.versions_flye)

    if (ch_genomad_db) {
        GENOMAD_ENDTOEND (
            ch_contigs,
            ch_genomad_db
        )
        ch_plasmids = GENOMAD_ENDTOEND.out.plasmid_summary
        ch_versions = ch_versions.mix(GENOMAD_ENDTOEND.out.versions_genomad)
    }

    emit:
    contigs     = ch_contigs
    assembly_gfa= FLYE.out.gfa
    assembly_txt= FLYE.out.txt
    assembly_log= FLYE.out.log
    plasmids    = ch_plasmids
    versions    = ch_versions
}
