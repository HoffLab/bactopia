#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/
SCHEMAS = []
CUSTOM_STEPS = [:]
params.workflows[params.wf]['includes'].each { it ->
    SCHEMAS << "${params.workflows[it].schema}"
    CUSTOM_STEPS[it] = true
}
SCHEMAS << 'conf/schema/generic.json'
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

// Custom Steps (based on includes)
if (CUSTOM_STEPS.containsKey("staphtyper") {
    include { STAPHTYPER } from '../subworkflows/local/staphtyper/main'
}

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/
workflow BACTOPIA {
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

    // Run Custom Steps
    if (CUSTOM_STEPS.containsKey("staphtyper") {
        // Staphylococcus aureus specific
        STAPHTYPER(ASSEMBLE_GENOME.out.fna_only)
    }
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
