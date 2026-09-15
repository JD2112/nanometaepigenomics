include { MODKIT_PILEUP              } from '../../../modules/nf-core/modkit/pileup/main'
include { NANOMOTIF_FIND_MOTIFS      } from '../../../modules/local/nanomotif/find_motifs/main'
include { AMRFINDERPLUS_RUN          } from '../../../modules/nf-core/amrfinderplus/run/main'
include { ABRICATE_RUN               } from '../../../modules/nf-core/abricate/run/main'
include { PLASMIDFINDER              } from '../../../modules/nf-core/plasmidfinder/main'
include { BAKTA_BAKTA                } from '../../../modules/nf-core/bakta/bakta/main'

workflow METAEPIGENOMICS_ANNOTATION {
    take:
    ch_bam_bai     // channel: [ val(meta), path(bam), path(bai) ]
    ch_contigs     // channel: [ val(meta), path(contigs) ]
    ch_bins        // channel: [ val(meta), path(bins_dir_or_files) ]
    ch_amr_db      // channel: [ val(meta), path(db) ] (optional)
    ch_bakta_db    // channel: [ val(meta), path(db) ] (optional)

    main:
    ch_versions = channel.empty()
    ch_motifs   = channel.empty()
    ch_amr      = channel.empty()
    ch_virulence= channel.empty()
    ch_plasmids = channel.empty()

    // 1. Modkit Pileup (bedMethyl)
    MODKIT_PILEUP (
        ch_bam_bai,
        ch_contigs.map { meta, contigs -> [ meta, contigs, [] ] },
        [ [id:'empty'], [] ]
    )
    ch_versions = ch_versions.mix(MODKIT_PILEUP.out.versions_modkit)

    // 2. Nanomotif motif discovery & bin/plasmid linkage
    ch_nanomotif_in = ch_contigs
        .join(MODKIT_PILEUP.out.bedgz)
        .join(ch_bins)

    NANOMOTIF_FIND_MOTIFS (
        ch_nanomotif_in
    )
    ch_motifs   = NANOMOTIF_FIND_MOTIFS.out.motifs
    ch_versions = ch_versions.mix(NANOMOTIF_FIND_MOTIFS.out.versions_nanomotif)

    // 3. AMRFinderPlus on contigs / MAGs
    if (ch_amr_db) {
        AMRFINDERPLUS_RUN (
            ch_contigs,
            ch_amr_db
        )
        ch_amr      = AMRFINDERPLUS_RUN.out.report
        ch_versions = ch_versions.mix(AMRFINDERPLUS_RUN.out.versions_amrfinderplus)
    }

    // 4. Abricate with VFDB (Virulence factors)
    ABRICATE_RUN (
        ch_contigs,
        []
    )
    ch_virulence= ABRICATE_RUN.out.report
    ch_versions = ch_versions.mix(ABRICATE_RUN.out.versions_abricate)

    // 5. PlasmidFinder
    PLASMIDFINDER (
        ch_contigs
    )
    ch_plasmids = PLASMIDFINDER.out.tsv
    ch_versions = ch_versions.mix(PLASMIDFINDER.out.versions_plasmidfinder)

    // 6. Bakta functional annotation
    if (ch_bakta_db) {
        BAKTA_BAKTA (
            ch_contigs,
            ch_bakta_db,
            [],
            [],
            [],
            []
        )
        ch_versions = ch_versions.mix(BAKTA_BAKTA.out.versions_bakta)
    }

    emit:
    bedgz       = MODKIT_PILEUP.out.bedgz
    motifs      = ch_motifs
    amr_report  = ch_amr
    virulence   = ch_virulence
    plasmids    = ch_plasmids
    versions    = ch_versions
}
