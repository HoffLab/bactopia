#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/
include { create_input_channel; setup_datasets } from '../lib/nf/bactopia'
include { get_resources; get_schemas; print_efficiency } from '../lib/nf/functions'
RESOURCES = get_resources(workflow.profile, params.max_memory, params.max_cpus)

/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/
SCHEMAS = get_schemas()
WorkflowMain.initialise(workflow, params, log, schema_filename=SCHEMAS)
run_type = WorkflowBactopia.initialise(workflow, params, log, schema_filename=SCHEMAS)

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/
include { create_input_channel; setup_datasets } from '../lib/nf/bactopia'
include { get_resources; print_efficiency } from '../lib/nf/functions'
RESOURCES = get_resources(workflow.profile, params.max_memory, params.max_cpus)

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

// Core
include { ANNOTATE_GENOME } from '../modules/local/bactopia/annotate_genome/main'
include { ASSEMBLE_GENOME } from '../modules/local/bactopia/assemble_genome/main'
include { ASSEMBLY_QC } from '../modules/local/bactopia/assembly_qc/main'
include { GATHER_SAMPLES } from '../modules/local/bactopia/gather_samples/main'
include { MINMER_SKETCH } from '../modules/local/bactopia/minmer_sketch/main'
include { QC_READS } from '../modules/local/bactopia/qc_reads/main'

// Require Datasets
include { ANTIMICROBIAL_RESISTANCE } from '../modules/local/bactopia/antimicrobial_resistance/main'
include { ARIBA_ANALYSIS } from '../modules/local/bactopia/ariba_analysis/main'
include { BLAST } from '../modules/local/bactopia/blast/main'
include { CALL_VARIANTS } from '../modules/local/bactopia/call_variants/main'
include { MAPPING_QUERY } from '../modules/local/bactopia/mapping_query/main'
include { MINMER_QUERY } from '../modules/local/bactopia/minmer_query/main'
include { SEQUENCE_TYPE } from '../modules/local/bactopia/sequence_type/main'

// Staphylococcus aureus specific
include { STAPHTYPER } from '../subworkflows/local/staphtyper/main' addParams(is_main: true)

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'  addParams( options: [publish_to_base: true] )

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/
workflow STAPHOPIA {
    print_efficiency(RESOURCES.MAX_CPUS) 
    datasets = setup_datasets()

    // Core steps
    GATHER_SAMPLES(create_input_channel(run_type, datasets['genome_size']))
    QC_READS(GATHER_SAMPLES.out.raw_fastq)
    ASSEMBLE_GENOME(QC_READS.out.fastq_assembly)
    ASSEMBLY_QC(ASSEMBLE_GENOME.out.fna, Channel.fromList(['checkm', 'quast']))
    ANNOTATE_GENOME(ASSEMBLE_GENOME.out.fna, Channel.fromPath(datasets['proteins']), Channel.fromPath(datasets['training_set']))
    MINMER_SKETCH(QC_READS.out.fastq)

    // Optional steps that require datasets
    // Species agnostic
    ANTIMICROBIAL_RESISTANCE(ANNOTATE_GENOME.out.annotations, datasets['amr'])
    ARIBA_ANALYSIS(QC_READS.out.fastq, datasets['ariba'])
    MINMER_QUERY(MINMER_SKETCH.out.sketch, datasets['minmer'])

    // Species Specific
    BLAST(ASSEMBLE_GENOME.out.blastdb, datasets['blast'])
    CALL_VARIANTS(QC_READS.out.fastq, datasets['references'])
    MAPPING_QUERY(QC_READS.out.fastq, datasets['mapping'])
    SEQUENCE_TYPE(ASSEMBLE_GENOME.out.fna_fastq, datasets['mlst'])

    // Staphylococcus aureus specific
    STAPHTYPER(ASSEMBLE_GENOME.out.fna_only)

    // Collect Versions
    ch_versions = Channel.empty()
    ch_versions = ch_versions.mix(GATHER_SAMPLES.out.versions.first())
    ch_versions = ch_versions.mix(QC_READS.out.versions.first())
    ch_versions = ch_versions.mix(ASSEMBLE_GENOME.out.versions.first())
    ch_versions = ch_versions.mix(ASSEMBLY_QC.out.versions.first())
    ch_versions = ch_versions.mix(ANNOTATE_GENOME.out.versions.first())
    ch_versions = ch_versions.mix(MINMER_SKETCH.out.versions.first())
    ch_versions = ch_versions.mix(ANTIMICROBIAL_RESISTANCE.out.versions.first())
    ch_versions = ch_versions.mix(MINMER_QUERY.out.versions.first())
    ch_versions = ch_versions.mix(BLAST.out.versions.first())
    ch_versions = ch_versions.mix(CALL_VARIANTS.out.versions.first())
    ch_versions = ch_versions.mix(MAPPING_QUERY.out.versions.first())
    ch_versions = ch_versions.mix(SEQUENCE_TYPE.out.versions.first())
    ch_versions = ch_versions.mix(STAPHTYPER.out.versions.first())
    CUSTOM_DUMPSOFTWAREVERSIONS(ch_versions.unique().collectFile())
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/
workflow.onComplete {
    workDir = new File("${workflow.workDir}")

    println """
    Bactopia Execution Summary
    ---------------------------
    Bactopia Version : ${workflow.manifest.version}
    Nextflow Version : ${nextflow.version}
    Command Line     : ${workflow.commandLine}
    Resumed          : ${workflow.resume}
    Completed At     : ${workflow.complete}
    Duration         : ${workflow.duration}
    Success          : ${workflow.success}
    Exit Code        : ${workflow.exitStatus}
    Error Report     : ${workflow.errorReport ?: '-'}
    Launch Dir       : ${workflow.launchDir}
    """
}

/*
========================================================================================
    THE END
========================================================================================
*/
