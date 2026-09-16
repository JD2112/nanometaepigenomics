<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/nf-core-nanometaepigenomics_logo_dark.png">
    <img alt="nf-core/nanometaepigenomics" src="docs/images/nf-core-nanometaepigenomics_logo_light.png">
  </picture>
</h1>

[![Open in GitHub Codespaces](https://img.shields.io/badge/Open_In_GitHub_Codespaces-black?labelColor=grey&logo=github)](https://github.com/codespaces/new/nf-core/nanometaepigenomics)
[![GitHub Actions CI Status](https://github.com/nf-core/nanometaepigenomics/actions/workflows/nf-test.yml/badge.svg)](https://github.com/nf-core/nanometaepigenomics/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/nf-core/nanometaepigenomics/actions/workflows/linting.yml/badge.svg)](https://github.com/nf-core/nanometaepigenomics/actions/workflows/linting.yml)[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/nanometaepigenomics/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.10.4-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-4.1.0-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/4.1.0)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/nf-core/nanometaepigenomics)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23nanometaepigenomics-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/nanometaepigenomics)[![Follow on Bluesky](https://img.shields.io/badge/bluesky-%40nf__core-1185fe?labelColor=000000&logo=bluesky)](https://bsky.app/profile/nf-co.re)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

**nf-core/nanometaepigenomics** is a clinical-grade, reproducible bioinformatics pipeline designed for Oxford Nanopore Technologies (ONT) metagenomic sequencing. It couples high-accuracy long-read assembly and metagenome-assembled genome (MAG) recovery with native bacterial epigenetic profiling (5mC/5hmC methylation calling and motif identification).

The pipeline is optimized for food safety, agricultural, and clinical pathogen surveillance where understanding bacterial strain diversity, mobile genetic elements (plasmids/phages), antimicrobial resistance (AMR), and host-contaminant depletion is critical.

### Pipeline Summary

1. **Raw Read Preflight QC**: Run [`NanoPlot`](https://github.com/wdecoster/NanoPlot) on raw long reads.
2. **Basecalling & Quality Preprocessing**:
   - Optional GPU-accelerated basecalling & modified base calling with [`Dorado`](https://github.com/nanoporetech/dorado).
   - Adapter and chimera trimming using [`Porechop_ABI`](https://github.com/bonsai-team/Porechop_ABI).
   - Length and quality filtering using [`Filtlong`](https://github.com/rrwick/Filtlong).
3. **Decontamination & Host Depletion**:
   - Two-stage read screening and removal using [`Minimap2`](https://github.com/lh3/minimap2) and [`Samtools`](http://www.htslib.org/):
     - Stage 1: Discard human host reads (GRCh38) for privacy and clinical compliance.
     - Stage 2: Deplete food-host or background host reads (e.g., plant or animal tissue).
   - Decontamination metrics and depth reporting via [`Mosdepth`](https://github.com/brentp/mosdepth).
4. **Metagenomic Assembly & Classification**:
   - De novo long-read metagenome assembly with [`metaFlye`](https://github.com/fenderglass/Flye).
   - Plasmid and viral sequence identification via [`geNomad`](https://github.com/apcamargo/genomad).
5. **Binning, QC & Taxonomy**:
   - Read mapping to contigs with [`Minimap2`](https://github.com/lh3/minimap2) and depth calculation with [`MetaBAT2 (jgi_summarize_bam_contig_depths)`](https://bitbucket.org/berkeleylab/metabat).
   - Metagenomic binning with [`MetaBAT2`](https://bitbucket.org/berkeleylab/metabat) (or [`SemiBin2`](https://github.com/BigDataBiology/SemiBin)).
   - MAG completeness & contamination estimation with [`CheckM2`](https://github.com/chklovski/CheckM2).
   - Taxonomic classification with [`GTDB-Tk`](https://github.com/Ecogenomics/GTDBTk).
6. **Meta-epigenomics & Functional Annotation**:
   - Native methylation pileup generation with [`Modkit`](https://github.com/nanoporetech/modkit).
   - Methylation motif discovery and plasmid-to-host bin linkage with [`Nanomotif`](https://github.com/nanoporetech/nanomotif).
   - Antimicrobial resistance detection with [`AMRFinderPlus`](https://github.com/ncbi/amr).
   - Virulence factor screening with [`ABRICATE (VFDB)`](https://github.com/tseemann/abricate).
   - Plasmid replicon typing with [`PlasmidFinder`](https://bitbucket.org/genomicepidemiology/plasmidfinder).
   - MAG functional annotation with [`Bakta`](https://github.com/oschwengers/bakta).
7. **Reporting & Audit Trail**:
   - Standardized clinical audit-trail manifest (`*_run_manifest.json`) and clinical summary table (`*_clinical_report.tsv`).
   - Summary report with [`MultiQC`](http://multiqc.info/).

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/get_started/environment_setup/overview) on how to set-up Nextflow.

Prepare a samplesheet with your input data (BAM or gzipped FASTQ):

`samplesheet.csv`:

```csv
sample,fastq_1,fastq_2
SAMPLE1,/path/to/sample1.fastq.gz,
SAMPLE2,/path/to/sample2.fastq.gz,
```

Launch the pipeline:

```bash
nextflow run nf-core/nanometaepigenomics \
   -profile <docker/singularity/conda> \
   --input samplesheet.csv \
   --human_fasta /path/to/GRCh38.fa \
   --host_fasta /path/to/food_host.fa \
   --outdir results/
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/running/run-pipelines#using-parameter-files).

For more details and further functionality, please refer to the [usage documentation](docs/usage.md) and the [output documentation](docs/output.md).

## Pipeline output

To see the results of an example test run with a full size dataset refer to the [results](https://nf-co.re/nanometaepigenomics/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://nf-co.re/nanometaepigenomics/output).

## Credits

nf-core/nanometaepigenomics was originally written by Jyotirmoy Das.

We thank the following people for their extensive assistance in the development of this pipeline:

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](docs/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#nanometaepigenomics` channel](https://nfcore.slack.com/channels/nanometaepigenomics) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use nf-core/nanometaepigenomics for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
