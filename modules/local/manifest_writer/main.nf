process MANIFEST_WRITER {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.9--1' :
        'quay.io/biocontainers/python:3.9--1' }"

    input:
    tuple val(meta), path(decontam_stats), path(checkm2_tsv), path(amr_tsv), path(motifs_tsv)
    val pipeline_version

    output:
    tuple val(meta), path("*_run_manifest.json"), emit: manifest_json
    tuple val(meta), path("*_summary.tsv"), emit: summary_tsv
    tuple val("${task.process}"), val('python'), eval('python3 --version | sed "s/Python //"'), emit: versions_python, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    python3 << 'PYEOF'
import json
import os
import sys

sample_id = "${meta.id}"
pipeline_version = "${pipeline_version}"

manifest = {
    "sample_id": sample_id,
    "pipeline": "nf-core/nanometaepigenomics",
    "version": pipeline_version,
    "status": "COMPLETED",
    "decontamination_metrics": {},
    "checkm2_metrics": {},
    "amr_findings": [],
    "discovered_motifs": []
}

# Decontamination stats
for f in ["${decontam_stats}".split()]:
    for path in f:
        if os.path.exists(path) and os.path.isfile(path):
            with open(path) as inf:
                lines = [l.strip().split('\\t') for l in inf if l.strip()]
                if len(lines) > 1:
                    header = lines[0]
                    for row in lines[1:]:
                        stage = row[1] if len(row) > 1 else "unknown"
                        manifest["decontamination_metrics"][stage] = dict(zip(header, row))

# CheckM2
if os.path.exists("${checkm2_tsv}") and os.path.isfile("${checkm2_tsv}"):
    with open("${checkm2_tsv}") as inf:
        lines = [l.strip().split('\\t') for l in inf if l.strip()]
        if len(lines) > 1:
            header = lines[0]
            manifest["checkm2_metrics"] = [dict(zip(header, row)) for row in lines[1:]]

# AMR
if os.path.exists("${amr_tsv}") and os.path.isfile("${amr_tsv}"):
    with open("${amr_tsv}") as inf:
        lines = [l.strip().split('\\t') for l in inf if l.strip()]
        if len(lines) > 1:
            header = lines[0]
            manifest["amr_findings"] = [dict(zip(header, row)) for row in lines[1:]]

# Motifs
if os.path.exists("${motifs_tsv}") and os.path.isfile("${motifs_tsv}"):
    with open("${motifs_tsv}") as inf:
        lines = [l.strip().split('\\t') for l in inf if l.strip()]
        if len(lines) > 1:
            header = lines[0]
            manifest["discovered_motifs"] = [dict(zip(header, row)) for row in lines[1:]]

with open(f"${prefix}_run_manifest.json", "w") as outf:
    json.dump(manifest, outf, indent=2)

with open(f"${prefix}_summary.tsv", "w") as outf:
    outf.write(f"sample\\tstatus\\tversion\\n{sample_id}\\tCOMPLETED\\t{pipeline_version}\\n")
PYEOF
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo '{"sample_id": "${meta.id}", "status": "STUB"}' > ${prefix}_run_manifest.json
    echo -e "sample\\tstatus\\n${meta.id}\\tSTUB" > ${prefix}_summary.tsv
    """
}
