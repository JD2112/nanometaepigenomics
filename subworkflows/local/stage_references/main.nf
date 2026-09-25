include { DOWNLOAD_REFERENCE       } from '../../../modules/local/download/reference/main'
include { DOWNLOAD_AMRFINDER_DB    } from '../../../modules/local/download/amrfinder/main'
include { CHECKM2_DATABASEDOWNLOAD } from '../../../modules/nf-core/checkm2/databasedownload/main'
include { DOWNLOAD_GENOMAD_DB      } from '../../../modules/local/download/genomad/main'
include { DOWNLOAD_BAKTA_DB         } from '../../../modules/local/download/bakta/main'

// Pre-curated dictionary of high-confidence reference genomes
def getCuratedHostUrl(host_key) {
    def host_map = [
        'bos_taurus':        'https://ftp.ensembl.org/pub/current_fasta/bos_taurus/dna/Bos_taurus.ARS-UCD2.0.dna.toplevel.fa.gz',
        'cow':               'https://ftp.ensembl.org/pub/current_fasta/bos_taurus/dna/Bos_taurus.ARS-UCD2.0.dna.toplevel.fa.gz',
        'beef':              'https://ftp.ensembl.org/pub/current_fasta/bos_taurus/dna/Bos_taurus.ARS-UCD2.0.dna.toplevel.fa.gz',
        'sus_scrofa':        'https://ftp.ensembl.org/pub/current_fasta/sus_scrofa/dna/Sus_scrofa.Sscrofa11.1.dna.toplevel.fa.gz',
        'pig':               'https://ftp.ensembl.org/pub/current_fasta/sus_scrofa/dna/Sus_scrofa.Sscrofa11.1.dna.toplevel.fa.gz',
        'pork':              'https://ftp.ensembl.org/pub/current_fasta/sus_scrofa/dna/Sus_scrofa.Sscrofa11.1.dna.toplevel.fa.gz',
        'gallus_gallus':     'https://ftp.ensembl.org/pub/current_fasta/gallus_gallus/dna/Gallus_gallus.bGalGal1.mat.broiler.GRCg7b.dna.toplevel.fa.gz',
        'chicken':           'https://ftp.ensembl.org/pub/current_fasta/gallus_gallus/dna/Gallus_gallus.bGalGal1.mat.broiler.GRCg7b.dna.toplevel.fa.gz',
        'poultry':           'https://ftp.ensembl.org/pub/current_fasta/gallus_gallus/dna/Gallus_gallus.bGalGal1.mat.broiler.GRCg7b.dna.toplevel.fa.gz',
        'ovis_aries':        'https://ftp.ensembl.org/pub/current_fasta/ovis_aries/dna/Ovis_aries.ARS-UI_Ramb_v3.0.dna.toplevel.fa.gz',
        'sheep':             'https://ftp.ensembl.org/pub/current_fasta/ovis_aries/dna/Ovis_aries.ARS-UI_Ramb_v3.0.dna.toplevel.fa.gz',
        'salmo_salar':       'https://ftp.ensembl.org/pub/current_fasta/salmo_salar/dna/Salmo_salar.Ssal_v3.1.dna.toplevel.fa.gz',
        'salmon':            'https://ftp.ensembl.org/pub/current_fasta/salmo_salar/dna/Salmo_salar.Ssal_v3.1.dna.toplevel.fa.gz'
    ]
    def key = host_key.toLowerCase().trim()
    return host_map.containsKey(key) ? host_map[key] : null
}

def HUMAN_GRCH38_URL = 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz'

workflow STAGE_REFERENCES {
    take:
    val_human_fasta   // string or null
    val_host_fasta    // string or null (can be comma-separated or glob)
    val_host_names    // string or null (e.g. "bos_taurus,gallus_gallus")
    val_download_dbs  // boolean
    val_cache_dir     // string or null
    val_checkm2_db    // string or null
    val_amr_db        // string or null
    val_genomad_db    // string or null
    val_gtdb_db       // string or null
    val_bakta_db      // string or null

    main:
    ch_versions   = channel.empty()
    ch_human_ref  = channel.empty()
    ch_hosts_ref  = channel.empty()
    ch_checkm2_out= channel.empty()
    ch_amr_out    = channel.empty()
    ch_genomad_out= channel.empty()
    ch_gtdb_out   = channel.empty()
    ch_bakta_out  = channel.empty()

    // -------------------------------------------------------------
    // 1. Human Reference (GRCh38)
    // -------------------------------------------------------------
    if (val_human_fasta) {
        ch_human_ref = channel.fromPath(val_human_fasta, checkIfExists: true).map { [ [id:'human'], it ] }
    } else if (val_download_dbs) {
        DOWNLOAD_REFERENCE( channel.of( [ [id:'GRCh38_human'], HUMAN_GRCH38_URL ] ) )
        ch_human_ref = DOWNLOAD_REFERENCE.out.fasta
        ch_versions  = ch_versions.mix(DOWNLOAD_REFERENCE.out.versions_curl)
    }

    // -------------------------------------------------------------
    // 2. Food Matrix Host Reference(s)
    // -------------------------------------------------------------
    // A) User-supplied FASTA paths (comma-separated or single)
    if (val_host_fasta) {
        def paths = val_host_fasta.tokenize(',').collect { it.trim() }
        ch_hosts_from_paths = channel.fromPath(paths, checkIfExists: true)
            .map { f -> [ [id: f.baseName.replaceAll(/\\.(fa|fna|fasta).*/, '')], f ] }
        ch_hosts_ref = ch_hosts_ref.mix(ch_hosts_from_paths)
    }

    // B) Host species names declared via --host (e.g. "bos_taurus, chicken")
    if (val_host_names && val_download_dbs) {
        def host_list = val_host_names.tokenize(',').collect { it.trim() }
        def download_tuples = []
        host_list.each { h ->
            def url = getCuratedHostUrl(h)
            if (url) {
                download_tuples << [ [id: h], url ]
            } else {
                log.warn "Host preset '${h}' not found in curated dictionary. Please specify FASTA path via --host_fasta."
            }
        }
        if (download_tuples.size() > 0) {
            DOWNLOAD_HOST( channel.of(*download_tuples) )
            ch_hosts_ref = ch_hosts_ref.mix(DOWNLOAD_HOST.out.fasta)
            ch_versions  = ch_versions.mix(DOWNLOAD_HOST.out.versions_curl)
        }
    }

    // -------------------------------------------------------------
    // 3. CheckM2 Database
    // -------------------------------------------------------------
    if (val_checkm2_db) {
        ch_checkm2_out = channel.fromPath(val_checkm2_db, checkIfExists: true).map { [ [id:'checkm2_db'], it ] }
    } else if (val_download_dbs) {
        CHECKM2_DATABASEDOWNLOAD( [] )
        ch_checkm2_out = CHECKM2_DATABASEDOWNLOAD.out.database
        ch_versions    = ch_versions.mix(CHECKM2_DATABASEDOWNLOAD.out.versions_checkm2_databasedownload)
    }

    // -------------------------------------------------------------
    // 4. AMRFinderPlus Database
    // -------------------------------------------------------------
    if (val_amr_db) {
        ch_amr_out = channel.fromPath(val_amr_db, checkIfExists: true).map { [ [id:'amr_db'], it ] }
    } else if (val_download_dbs) {
        DOWNLOAD_AMRFINDER_DB()
        ch_amr_out  = DOWNLOAD_AMRFINDER_DB.out.db.map { [ [id:'amr_db'], it ] }
        ch_versions = ch_versions.mix(DOWNLOAD_AMRFINDER_DB.out.versions_amrfinder)
    }

    // -------------------------------------------------------------
    // 5. geNomad Database
    // -------------------------------------------------------------
    if (val_genomad_db) {
        ch_genomad_out = channel.fromPath(val_genomad_db, checkIfExists: true).map { [ [id:'genomad_db'], it ] }
    } else if (val_download_dbs) {
        DOWNLOAD_GENOMAD_DB()
        ch_genomad_out = DOWNLOAD_GENOMAD_DB.out.db.map { [ [id:'genomad_db'], it ] }
        ch_versions    = ch_versions.mix(DOWNLOAD_GENOMAD_DB.out.versions_genomad)
    }

    // -------------------------------------------------------------
    // 6. GTDB-Tk Database
    // -------------------------------------------------------------
    if (val_gtdb_db) {
        ch_gtdb_out = channel.fromPath(val_gtdb_db, checkIfExists: true).map { [ [id:'gtdb_db'], it ] }
    }

    // -------------------------------------------------------------
    // 7. Bakta Database
    // -------------------------------------------------------------
    if (val_bakta_db) {
        ch_bakta_out = channel.fromPath(val_bakta_db, checkIfExists: true).map { [ [id:'bakta_db'], it ] }
    } else if (val_download_dbs) {
        DOWNLOAD_BAKTA_DB( channel.of( [id:'bakta_db'] ) )
        ch_bakta_out = DOWNLOAD_BAKTA_DB.out.db
        ch_versions  = ch_versions.mix(DOWNLOAD_BAKTA_DB.out.versions_bakta)
    }

    emit:
    human_ref   = ch_human_ref
    hosts_ref   = ch_hosts_ref
    checkm2_db  = ch_checkm2_out
    amr_db      = ch_amr_out
    genomad_db  = ch_genomad_out
    gtdb_db     = ch_gtdb_out
    bakta_db    = ch_bakta_out
    versions    = ch_versions
}

// Alias for downloading multiple host organisms in parallel
include { DOWNLOAD_REFERENCE as DOWNLOAD_HOST } from '../../../modules/local/download/reference/main'
