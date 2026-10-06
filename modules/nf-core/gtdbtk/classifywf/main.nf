process GTDBTK_CLASSIFYWF {
    tag "${meta.id}"
    label 'process_high_memory'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/gtdbtk:2.4.0--pyhdfd78af_1'
        : 'quay.io/biocontainers/gtdbtk:2.4.0--pyhdfd78af_1'}"

    input:
    tuple val(meta)   , path("bins/*")
    tuple val(db_name), path(db)
    val use_pplacer_scratch_dir

    output:
    tuple val(meta), path("${prefix}")                               , emit: gtdb_outdir
    tuple val(meta), path("${prefix}/classify/*.summary.tsv")        , emit: summary
    tuple val(meta), path("${prefix}/classify/*.classify.tree")      , emit: tree       , optional: true
    tuple val(meta), path("${prefix}/identify/*.markers_summary.tsv"), emit: markers    , optional: true
    tuple val(meta), path("${prefix}/align/*.msa.fasta.gz")          , emit: msa        , optional: true
    tuple val(meta), path("${prefix}/align/*.user_msa.fasta.gz")     , emit: user_msa   , optional: true
    tuple val(meta), path("${prefix}/align/*.filtered.tsv")          , emit: filtered   , optional: true
    tuple val(meta), path("${prefix}/identify/*.failed_genomes.tsv") , emit: failed     , optional: true
    tuple val(meta), path("${prefix}/${prefix}.log")                 , emit: log
    tuple val(meta), path("${prefix}/${prefix}.warnings.log")        , emit: warnings
    tuple val("${task.process}"), val('gtdbtk'), eval("gtdbtk --version 2>&1 | grep -Eo '[0-9]+(\\.[0-9]+)+' | head -1") , topic: versions, emit: versions_gtdbtk
    tuple val("${task.process}"), val('gtdb_db'), eval('grep VERSION_DATA \$GTDBTK_DATA_PATH/metadata/metadata.txt | sed "s/VERSION_DATA=//"'), topic: versions, emit: versions_gtdbtk_db

    when:
    task.ext.when == null || task.ext.when

    script:
    def args            = task.ext.args ?: ''
    prefix              = task.ext.prefix ?: "${meta.id}"
    def pplacer_scratch = use_pplacer_scratch_dir ? "--scratch_dir pplacer_tmp" : ""
    """
    # Locate GTDBTK_DATA_PATH
    if [ -d "${db}/metadata" ] || [ -d "${db}/skani" ] || [ -f "${db}/VERSION" ]; then
        export GTDBTK_DATA_PATH="${db}"
    else
        RESOLVED_PATH=\$(find -L "${db}" -maxdepth 3 -name 'metadata' -type d -exec dirname {} \\; | head -n 1)
        if [ -n "\$RESOLVED_PATH" ]; then
            export GTDBTK_DATA_PATH="\$RESOLVED_PATH"
        else
            export GTDBTK_DATA_PATH="${db}"
        fi
    fi
    echo "Using GTDBTK_DATA_PATH: \$GTDBTK_DATA_PATH"

    if [ "${pplacer_scratch}" != "" ] ; then
        mkdir pplacer_tmp
    fi

    # Standardize genome extensions in bins/ so GTDB-Tk recognizes both bins and raw contigs
    for f in bins/*.fasta.gz bins/*.fa.gz bins/*.fna.gz; do
        [ -f "\$f" ] && mv "\$f" "\${f%.*.*}.fa.gz" 2>/dev/null || true
    done
    for f in bins/*.fasta bins/*.fna; do
        [ -f "\$f" ] && mv "\$f" "\${f%.*}.fa" 2>/dev/null || true
    done

    # If all bins are compressed (.fa.gz), use --extension .fa.gz, otherwise .fa
    EXT="fa"
    if ls bins/*.fa.gz 1>/dev/null 2>&1; then
        EXT="fa.gz"
    fi

    # In GTDB-Tk <= 2.4.0, classify_wf requires either --mash_db <file> or --skip_ani_screen
    ANI_SCREEN_OPT="--skip_ani_screen"
    MASH_FILE=\$(find -L "\$GTDBTK_DATA_PATH" -name "*.msh" 2>/dev/null | head -n 1)
    if [ -n "\$MASH_FILE" ]; then
        ANI_SCREEN_OPT="--mash_db \$MASH_FILE"
    fi

    gtdbtk classify_wf \\
        ${args} \\
        \${ANI_SCREEN_OPT} \\
        --extension "\${EXT}" \\
        --genome_dir bins \\
        --prefix "${prefix}" \\
        --out_dir ${prefix} \\
        --cpus ${task.cpus} \\
        ${pplacer_scratch}

    mv ${prefix}/gtdbtk.log "${prefix}/${prefix}.log"
    mv ${prefix}/gtdbtk.warnings.log "${prefix}/${prefix}.warnings.log"
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    export GTDBTK_DATA_PATH="\$(find -L ${db} -name 'metadata' -type d -exec dirname {} \\;)"

    mkdir ${prefix}
    mkdir ${prefix}/identify
    mkdir ${prefix}/classify
    mkdir ${prefix}/align

    touch ${prefix}/classify/${prefix}.ar53.summary.tsv
    touch ${prefix}/classify/${prefix}.bac120.summary.tsv
    touch ${prefix}/classify/${prefix}.ar53.classify.tree
    touch ${prefix}/classify/${prefix}.bac120.classify.tree

    touch ${prefix}/identify/${prefix}.ar53.markers_summary.tsv
    touch ${prefix}/identify/${prefix}.bac120.markers_summary.tsv

    echo "" | gzip > ${prefix}/align/${prefix}.ar53.msa.fasta.gz
    echo "" | gzip > ${prefix}/align/${prefix}.bac120.user_msa.fasta.gz
    touch ${prefix}/align/${prefix}.ar53.filtered.tsv
    touch ${prefix}/align/${prefix}.bac120.filtered.tsv

    touch ${prefix}/${prefix}.log
    touch ${prefix}/${prefix}.warnings.log
    touch ${prefix}/${prefix}.failed_genomes.tsv
    """
}
