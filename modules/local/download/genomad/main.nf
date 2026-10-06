process DOWNLOAD_GENOMAD_DB {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/genomad:1.8.1--pyhdfd78af_0' :
        'quay.io/biocontainers/genomad:1.8.1--pyhdfd78af_0' }"

    output:
    path "genomad_db", emit: db
    tuple val("${task.process}"), val('genomad'), eval("genomad --version 2>&1 | sed 's/^.*geNomad, version //; s/ .*//'"), topic: versions, emit: versions_genomad

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    genomad download-database .
    """

    stub:
    """
    mkdir -p genomad_db
    touch genomad_db/version.txt
    """
}
