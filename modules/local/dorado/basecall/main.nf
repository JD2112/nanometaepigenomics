process DORADO_BASECALL {
    tag "$meta.id"
    label 'process_gpu'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/dorado:0.9.1--h9ee0642_0' :
        'ontresearch/dorado:latest' }"

    input:
    tuple val(meta), path(pod5)
    val model
    val modified_bases

    output:
    tuple val(meta), path("*.bam"), emit: bam
    tuple val(meta), path("*.summary.txt"), emit: summary, optional: true
    tuple val("${task.process}"), val('dorado'), eval('dorado --version 2>&1 | head -n1 | sed "s/dorado //"'), emit: versions_dorado, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mod_bases = modified_bases ? "--modified-bases ${modified_bases}" : ""
    def device = task.accelerator ? "--device cuda:all" : "--device cpu"
    """
    dorado basecaller \\
        ${model} \\
        ${pod5} \\
        ${mod_bases} \\
        ${device} \\
        ${args} \\
        > ${prefix}.calls.bam

    dorado summary ${prefix}.calls.bam > ${prefix}.sequencing_summary.txt || true
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.calls.bam
    touch ${prefix}.sequencing_summary.txt
    """
}
