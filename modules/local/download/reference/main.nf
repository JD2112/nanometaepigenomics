process DOWNLOAD_REFERENCE {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/curl:7.80.0' :
        'quay.io/biocontainers/curl:7.80.0' }"

    input:
    tuple val(meta), val(url)

    output:
    tuple val(meta), path("*.fna.gz"), emit: fasta
    tuple val("${task.process}"), val('curl'), eval('curl --version | head -n1'), emit: versions_curl, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    curl -L -f --retry 3 -o ${prefix}.fna.gz "${url}"
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.fna.gz
    """
}
