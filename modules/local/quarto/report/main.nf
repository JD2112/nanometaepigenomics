process QUARTO_REPORT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://jd21/milou_report:1.1.1' :
        'jd21/milou_report:1.1.1' }"

    input:
    tuple val(meta), path(manifest_json), path(checkm2_tsv), path(amr_tsv), path(vir_tsv), path(motifs_tsv), path(gtdb_tsv), path(decontam_tsv)
    path report_qmd
    path report_css

    output:
    tuple val(meta), path("${prefix}_report.html"), emit: html
    tuple val(meta), path("${prefix}_report.pdf") , emit: pdf , optional: true
    tuple val("${task.process}"), val('quarto'), eval('quarto --version'), emit: versions_quarto, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    export HOME=\$PWD
    export XDG_CACHE_HOME=\$PWD/quarto-cache
    export QUARTO_DATA_DIR=\$PWD/quarto-data
    export TEXMFVAR=\$PWD/texmf-var
    export TEXMFCONFIG=\$PWD/texmf-config
    export TMPDIR=\$PWD

    mkdir -p \$XDG_CACHE_HOME \$QUARTO_DATA_DIR \$TEXMFVAR \$TEXMFCONFIG

    # 1. Render standalone HTML report
    quarto render ${report_qmd} \\
        --to html \\
        -P manifest_json=${manifest_json} \\
        -P checkm2_tsv=${checkm2_tsv} \\
        -P amr_tsv=${amr_tsv} \\
        -P virulence_tsv=${vir_tsv} \\
        -P motifs_tsv=${motifs_tsv} \\
        -P gtdb_tsv=${gtdb_tsv} \\
        -P decontam_tsv=${decontam_tsv} \\
        -o ${prefix}_report.html \\
        ${args}

    # 2. Render publication-ready PDF report (using LaTeX in jd21/milou_report:1.1.1)
    quarto render ${report_qmd} \\
        --to pdf \\
        -P manifest_json=${manifest_json} \\
        -P checkm2_tsv=${checkm2_tsv} \\
        -P amr_tsv=${amr_tsv} \\
        -P virulence_tsv=${vir_tsv} \\
        -P motifs_tsv=${motifs_tsv} \\
        -P gtdb_tsv=${gtdb_tsv} \\
        -P decontam_tsv=${decontam_tsv} \\
        -o ${prefix}_report.pdf \\
        ${args} || true
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_report.html
    touch ${prefix}_report.pdf
    """
}
