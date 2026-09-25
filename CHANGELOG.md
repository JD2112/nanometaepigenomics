# nf-core/nanometaepigenomics: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0dev - [2026-09-25]

Initial release candidate of **nf-core/nanometaepigenomics** (`JD2112/nanometaepigenomics`), a clinical-grade DSL2 Nextflow pipeline for Oxford Nanopore Technologies (ONT) metagenomic sequencing and bacterial epigenetic profiling.

### `Added`

- **Raw Read QC & Preprocessing**:
  - `NanoPlot` for long-read quality control.
  - Optional `Dorado` basecalling and modified base calling (`4mC/5mC/6mA`).
  - `Porechop_ABI` adapter and chimera trimming.
  - `Filtlong` length and quality filtering.
- **Decontamination & Host Depletion**:
  - `STAGE_REFERENCES` subworkflow supporting automatic download and caching of host references and clinical databases.
  - 2-stage host depletion using `Minimap2` and `Samtools` (Stage 1: Human GRCh38; Stage 2: Food/Host background).
  - Coverage and depth calculation via `Mosdepth`.
- **Metagenomic Assembly & Binning**:
  - De novo long-read metagenomic assembly with `metaFlye`.
  - Plasmid and viral sequence identification via `geNomad`.
  - Metagenomic binning with `MetaBAT2` (`jgi_summarize_bam_contig_depths`).
  - MAG quality assessment with `CheckM2`.
  - Taxonomic classification with `GTDB-Tk` (Release r220/r214 auto-resolution).
- **Epigenomics & Functional Annotation**:
  - `Modkit` pileup generation (`bedMethyl`).
  - `Nanomotif` motif discovery and plasmid-to-host genome linkage.
  - `AMRFinderPlus` antimicrobial resistance gene identification.
  - `ABRICATE` (VFDB) virulence factor detection.
  - `PlasmidFinder` replicon typing.
  - `Bakta` genome functional annotation.
- **Reporting & Compliance**:
  - Standardized JSON run manifest (`*_run_manifest.json`) and clinical summary table (`*_clinical_report.tsv`).
  - Interactive Quarto HTML summary report (`quarto_report.html`).
  - `MultiQC` integration.

### `Fixed`

- Fixed GTDB-Tk database path resolution for GTDB release `r220` and container `gtdbtk:2.4.0--pyhdfd78af_1`.
- Added dynamic fallback in binning subworkflow when assembly produces 0 MAG bins (redirects raw assembly contigs to CheckM2, GTDB-Tk, Modkit, and Nanomotif).
- Added multi-modification model support (`4mC_5mC,6mA`) in Dorado module.
- Preserved MM/ML tags across Minimap2 BAM outputs for Modkit methylation pileup generation.

### `Dependencies`

- Nextflow `>=25.10.4`
- Python `3.10+`
- R / Quarto for report generation

