// Import generic module functions
include { get_resources; initOptions; saveFiles } from '../../../lib/nf/functions'
RESOURCES     = get_resources(workflow.profile, params.max_memory, params.max_cpus)
options       = initOptions(params.containsKey("options") ? params.options : [:], 'kleborate')
options.btype = options.btype ?: "tools"
conda_tools   = "bioconda::kleborate=2.2.0"
conda_name    = conda_tools.replace("=", "-").replace(":", "-").replace(" ", "-")
conda_env     = file("${params.condadir}/${conda_name}").exists() ? "${params.condadir}/${conda_name}" : conda_tools

process KLEBORATE {
    tag "$meta.id"
    label 'process_medium'
    publishDir params.outdir, mode: params.publish_dir_mode, overwrite: params.force,
        saveAs: { filename -> saveFiles(filename:filename, prefix:prefix, opts:options) }

    conda (params.enable_conda ? conda_env : null)
    container "${ workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/kleborate:2.2.0--pyhdfd78af_0' :
        'quay.io/biocontainers/kleborate:2.2.0--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(fastas)

    output:
    tuple val(meta), path("*.txt"), emit: txt
    path "*.{log,err}", emit: logs, optional: true
    path ".command.*", emit: nf_logs
    path "versions.yml",emit: versions

    script:
    def prefix = options.suffix ? "${options.suffix}" : "${meta.id}"
    """
    kleborate \\
        $options.args \\
        --outfile ${prefix}.results.txt \\
        --assemblies $fastas

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kleborate: \$( echo \$(kleborate --version | sed 's/Kleborate v//;'))
    END_VERSIONS
    """
}
