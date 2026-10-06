process DECONTAMINATION_FILTER_READS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.21--h50ea8bc_0' :
        'quay.io/biocontainers/samtools:1.21--h50ea8bc_0' }"

    input:
    tuple val(meta), path(bam)
    val stage_name

    output:
    tuple val(meta), path("*.clean.bam"), emit: bam
    tuple val(meta), path("*.stats.tsv"), emit: stats
    tuple val("${task.process}"), val('samtools'), eval('samtools --version | head -n1 | sed "s/samtools //"'), emit: versions_samtools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Total input reads
    total_reads=\$(samtools view -c ${bam})

    # Extract unmapped reads keeping all tags (MM, ML) intact (-f 4)
    samtools view -b -f 4 -@ ${task.cpus} ${bam} > ${prefix}.${stage_name}.clean.bam

    # Clean reads remaining
    clean_reads=\$(samtools view -c ${prefix}.${stage_name}.clean.bam)
    filtered_reads=\$((total_reads - clean_reads))

    echo -e "sample\\tstage\\ttotal_reads\\tfiltered_reads\\tclean_reads" > ${prefix}.${stage_name}.stats.tsv
    echo -e "${meta.id}\\t${stage_name}\\t\${total_reads}\\t\${filtered_reads}\\t\${clean_reads}" >> ${prefix}.${stage_name}.stats.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.${stage_name}.clean.bam
    echo -e "sample\\tstage\\ttotal_reads\\tfiltered_reads\\tclean_reads" > ${prefix}.${stage_name}.stats.tsv
    echo -e "${meta.id}\\t${stage_name}\\t1000\\t100\\t900" >> ${prefix}.${stage_name}.stats.tsv
    """
}
