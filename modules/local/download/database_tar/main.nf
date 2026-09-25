process DOWNLOAD_DATABASE_TAR {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/curl:7.80.0' :
        'quay.io/biocontainers/curl:7.80.0' }"

    input:
    tuple val(meta), val(url)

    output:
    tuple val(meta), path("db_dir"), emit: db
    tuple val("${task.process}"), val('curl'), eval('curl --version | head -n1'), emit: versions_curl, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p tmp_download db_dir
    curl -L -f --retry 3 -o tmp_download/${prefix}.tar.gz "${url}"
    tar -xzf tmp_download/${prefix}.tar.gz -C db_dir --strip-components 1 || tar -xzf tmp_download/${prefix}.tar.gz -C db_dir
    rm -rf tmp_download
    """

    stub:
    """
    mkdir -p db_dir
    touch db_dir/version.txt
    """
}
