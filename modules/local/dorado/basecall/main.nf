process DORADO_BASECALL {
    tag "$meta.id"
    label 'process_gpu'

    conda "${moduleDir}/environment.yml"
    container "docker.io/nanoporetech/dorado:sha38b4ce849afa13eac8075f0b41cecd30799f169b"

    input:
    tuple val(meta), path(pod5)
    val model
    val modified_bases

    output:
    tuple val(meta), path("*.bam"), emit: bam
    tuple val(meta), path("*.fastq.gz"), emit: reads
    tuple val(meta), path("*.summary.txt"), emit: summary, optional: true
    tuple val("${task.process}"), val('dorado'), eval('dorado --version 2>&1 | head -n1 | sed "s/dorado //"'), emit: versions_dorado, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mod_bases = modified_bases ? "--modified-bases ${modified_bases.replace(',', ' ')}" : ""
    def device = task.accelerator ? "--device cuda:all" : "--device cpu"
    def download_cmd = (model in ['sup', 'hac', 'fast']) ? "" : "dorado download --model ${model} || true"
    """
    export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
    ${download_cmd}

    dorado basecaller \\
        ${model} \\
        ${pod5} \\
        ${mod_bases} \\
        ${device} \\
        --batchsize 256 \\
        ${args} \\
        > ${prefix}.calls.bam

    dorado summary ${prefix}.calls.bam > ${prefix}.sequencing_summary.txt || true

    samtools fastq -T '*' ${prefix}.calls.bam | gzip -c > ${prefix}.fastq.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.calls.bam
    touch ${prefix}.sequencing_summary.txt
    """
}
