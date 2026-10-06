process NANOMOTIF_FIND_MOTIFS {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/nanomotif:1.1.2--pyhdfd78af_0' :
        'quay.io/biocontainers/nanomotif:1.1.2--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(assembly), path(pileup), path(bins_dir, stageAs: "bins_input/*")

    output:
    tuple val(meta), path("*_nanomotif"), emit: nanomotif_dir
    tuple val(meta), path("*_nanomotif/*.tsv"), emit: tsv, optional: true
    tuple val(meta), path("*_nanomotif/motifs.tsv"), emit: motifs, optional: true
    tuple val(meta), path("*_nanomotif/bin-motifs.tsv"), emit: bin_motifs, optional: true
    tuple val("${task.process}"), val('nanomotif'), eval('nanomotif --version | sed "s/nanomotif //"'), emit: versions_nanomotif, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    clean_assembly="${assembly}"
    if [[ "${assembly}" == *.gz ]]; then
        clean_assembly="\$(basename ${assembly} .gz)"
        gzip -dc ${assembly} > "\$clean_assembly"
    fi
    mkdir -p bins_dir
    if [ -d "bins_input" ]; then
        for f in bins_input/*.fa* bins_input/*.fasta*; do
            [ -f "\$f" ] && cp -L "\$f" bins_dir/ || true
        done
    fi

    # Uncompress any gzipped bins if present as nanomotif requires raw fasta
    for f in bins_dir/*.fa.gz bins_dir/*.fasta.gz; do
        [ -f "\$f" ] && gzip -d -f "\$f" || true
    done

    # Nanomotif defaults to looking for '.fasta' extension: normalize any .fa to .fasta
    for f in bins_dir/*.fa; do
        [ -f "\$f" ] && mv "\$f" "\${f%.fa}.fasta" || true
    done

    # Fallback: if bins_dir contains no .fasta files, copy assembly as unbinned.fasta
    if [ -z "\$(ls bins_dir/*.fasta 2>/dev/null)" ]; then
        cp -L "\$clean_assembly" bins_dir/unbinned.fasta
    fi

    # nanomotif requires a tabix index (.tbi) for the bed.gz pileup
    # Nextflow inputs are symlinks into the work dir (sometimes read-only or outside),
    # so copy pileup locally to ensure tabix can write the index alongside it
    cp -L ${pileup} pileup.bed.gz
    # nanomotif strictly supports modification codes 'm' (5mC/4mC) and 'a' (6mA).
    # Other marks like 'h' (5hmC) or unsupported codes cause RuntimeError.
    # We retain header lines and rows where column 4 is 'm', 'a', '21839', or begins with m/a.
    python3 - << 'EOF'
import gzip, pysam
with gzip.open('pileup.bed.gz', 'rt') as fin, open('pileup_clean.bed', 'w') as fout:
    for line in fin:
        if line.startswith('#'):
            fout.write(line)
            continue
        parts = line.strip().split('\t')
        if len(parts) > 3:
            mod = parts[3]
            # Convert 21839 (standard ChEBI 6mA) to 'a' if present
            if mod == '21839':
                parts[3] = 'a'
                print(*parts, sep='\t', file=fout)
            elif mod in ('m', 'a'):
                fout.write(line)
            elif mod == 'h':
                continue
            else:
                continue

pysam.tabix_compress('pileup_clean.bed', 'pileup.bed.gz', force=True)
pysam.tabix_index('pileup.bed.gz', preset='bed', force=True)
EOF

    nanomotif motif_discovery \\
        "\$clean_assembly" \\
        pileup.bed.gz \\
        -d bins_dir \\
        --extension .fasta \\
        --out ${prefix}_nanomotif \\
        -t ${task.cpus} \\
        ${args}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}_nanomotif
    touch ${prefix}_nanomotif/motifs.tsv
    touch ${prefix}_nanomotif/bin_motifs.tsv
    """
}
