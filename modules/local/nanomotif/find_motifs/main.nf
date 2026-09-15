process NANOMOTIF_FIND_MOTIFS {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/nanomotif:0.4.13--pyhdfd78af_0' :
        'quay.io/biocontainers/nanomotif:0.4.13--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(assembly), path(pileup), path(bins_dir)

    output:
    tuple val(meta), path("${prefix}_nanomotif/"), emit: nanomotif_dir
    tuple val(meta), path("${prefix}_nanomotif/motifs.tsv"), emit: motifs, optional: true
    tuple val(meta), path("${prefix}_nanomotif/bin_motifs.tsv"), emit: bin_motifs, optional: true
    tuple val("${task.process}"), val('nanomotif'), eval('nanomotif --version | sed "s/nanomotif //"'), emit: versions_nanomotif, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    nanomotif find_motifs \\
        ${assembly} \\
        ${pileup} \\
        ${bins_dir} \\
        --outdir ${prefix}_nanomotif \\
        --threads ${task.cpus} \\
        ${args}
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}_nanomotif
    touch ${prefix}_nanomotif/motifs.tsv
    touch ${prefix}_nanomotif/bin_motifs.tsv
    """
}
