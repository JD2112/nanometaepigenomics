# nf-core/nanometaepigenomics: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory (`--outdir`).

## Pipeline Overview & Directory Structure

```text
results/
├── qc/
│   └── nanoplot/                # NanoPlot raw read summary statistics and HTML reports
├── basecalling/
│   └── dorado/                  # Basecalled and 5mC/5hmC modified-base tagged BAMs and summaries
├── preprocessing/
│   ├── porechop/                # Adapter & chimera trimmed reads
│   └── filtlong/                # Length and quality filtered reads
├── decontamination/
│   ├── *_filtered.bam           # Depleted BAM files (decontaminated reads)
│   ├── *_decontamination_stats.txt # Quantification of removed human and host reads
│   └── mosdepth/                # Read coverage and depth distributions across reference hosts
├── assembly/
│   └── flye/                    # MetaFlye de novo metagenomic contigs, assembly info, and graphical fragments
├── classification/
│   └── genomad/                 # Identified plasmid and viral/phage sequences and classification scores
├── binning/
│   ├── metabat2/                # Metagenome-assembled genome (MAG) FASTA bins and depth tables
│   └── checkm2/                 # CheckM2 MAG completeness and contamination predictions (quality_report.tsv)
├── taxonomy/
│   └── gtdbtk/                  # GTDB-Tk taxonomic assignments and summary tables
├── methylation/
│   ├── modkit/                  # Modkit bedMethyl methylation pileup files (*.bed.gz)
│   └── nanomotif/               # Discovered methylation motifs and contig-to-bin association tables
├── annotation/
│   ├── amrfinderplus/           # AMRFinderPlus antimicrobial resistance gene reports
│   ├── virulence/               # ABRICATE VFDB virulence factor annotations
│   ├── plasmidfinder/           # PlasmidFinder replicon typing results
│   └── bakta/                   # Bakta functional annotation GFF3, GBK, and TSV files for MAGs
├── multiqc/
│   └── multiqc_report.html      # Comprehensive MultiQC HTML summary report
└── pipeline_info/
    ├── *_run_manifest.json      # Clinical audit trail manifest (MD5 checksums, run metadata, software versions)
    ├── *_clinical_report.tsv    # Unified clinical tabular summary
    ├── software_versions.yml    # Pinned versions of all tools used in the run
    └── execution_report.html     # Nextflow execution resource and timing report
```

### Manifest & Audit Trail

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - `*_run_manifest.json`: Machine-readable audit manifest containing tool version strings, run timestamps, parameter hashes, and output file MD5 checksums.
  - `*_clinical_report.tsv`: High-level clinical table synthesizing host depletion percentage, number of high-quality MAGs, detected AMR genes, and dominant methylation motifs.

</details>

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: Standalone interactive HTML report compiling NanoPlot, Porechop, Mosdepth, and software version tables.
  - `multiqc_data/`: Parsed JSON and tabular data from the report.

</details>

