process DOWNLOAD_BAKTA_DB {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "community.wave.seqera.io/library/bakta_diamond:7830b94718da4f96"

    input:
    val meta

    output:
    tuple val(meta), path("bakta_db"), emit: db
    tuple val("${task.process}"), val('bakta'), eval("bakta --version 2>&1 | sed 's/.*bakta //'"), emit: versions_bakta, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    mkdir -p nxf_home
    export HOME=\$PWD/nxf_home

    bakta_db download --output raw_db --type light

    # bakta_db download extracts into db-light/ or similar subdirectory.
    # Find the directory containing version.json and make bakta_db point directly to it.
    VFILE=\$(find raw_db -name "version.json" | head -n 1)
    if [ -n "\$VFILE" ]; then
        DB_DIR=\$(dirname "\$VFILE")
        mv "\$DB_DIR" bakta_db
    else
        mv raw_db bakta_db
    fi
    """

    stub:
    """
    mkdir -p bakta_db
    touch bakta_db/version.txt
    """
}
