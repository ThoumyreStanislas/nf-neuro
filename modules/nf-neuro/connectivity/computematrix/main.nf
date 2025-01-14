

process CONNECTIVITY_COMPUTEMATRIX {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'scil.usherbrooke.ca/containers/scilus_2.0.2.sif':
        'scilus/scilus:2.0.2' }"

    input:
    tuple val(meta), path(h5), path(atlas), path(atlas_labels), path(atlas_list), path(metrics), path(lesion), val(lesion_id)

    output:
    tuple val(meta), path("*_stat_*.npy")       , emit: stat
    tuple val(meta), path("*_seg-*_stat-*.npy") , emit: metrics
    tuple val(meta), path("*_lesion_*.npy")     , emit: lesions
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def prefix_lesion = "${lesion_id.id}_" ?: ""
    def atlas_names = task.ext.atlas_names ?: ""
    def with_lesion = task.ext.with_lesion ? "--lesion_load $lesion " : ""
    def density_weighting = task.ext.density_weighting ? "--density_weighting" : ""
    def no_self_connection = task.ext.with_lesion ? "--no_self_connection" : ""

    if ( metrics ) {metrics_list = metrics.join(", ").replace(',', '')}

    """
    metrics_args=""

    if [ -f $metrics ]; then
        for metric in $metrics_list; do
            base_name=\$(basename \${metric} .npy)

            # Fetch metric tag.
            stat=\$(echo "\$base_name" | cut -d'_' -f3)

            metrics_args="\${metrics_args} --metrics \${metric} ${prefix}_seg-${atlas_names}_stat-\${stat}.npy"
        done
    fi

    scil_connectivity_compute_matrices.py $h5 $atlas --force_labels_list $atlas_list \
        --volume ${prefix_lesion}${prefix}_${atlas_names}_stat_vol.npy \
        --streamline_count ${prefix_lesion}${prefix}_${atlas_names}_stat_sc.npy \
        --length ${prefix_lesion}${prefix}_${atlas_names}_stat_len.npy \
        $density_weighting $no_self_connection \$metrics_args \
        --include_dps ./ $with_lesion --processes $task.cpus

    if [ -f $lesion ]; then
        mv lesion_sc.npy ${prefix_lesion}${prefix}_${atlas_names}_lesion_sc.npy
        mv lesion_vol.npy ${prefix_lesion}${prefix}_${atlas_names}_lesion_vol.npy
        mv lesion_count.npy ${prefix_lesion}${prefix}_${atlas_names}_lesion_count.npy
    fi

    # Rename commit or afd_fixel files if they exist.
    if [ -f afd_fixel.npy ]; then
        mv afd_fixel.npy ${prefix}_seg-${atlas}_stat-afd_fixel.npy
    fi

    if [ -f commit*.npy ]; then
        mv commit*.npy ${prefix}_seg-${atlas}_stat-commit_weights.npy
    fi

    if [ -f tot_commit*.npy ]; then
        mv tot_commit*.npy ${prefix}_seg-${atlas}_stat-tot_commit_weights.npy
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def prefix_lesion = "${lesion_id.id}_" ?: ""
    def atlas_names = task.ext.atlas_names ?: ""

    """
    if [ -f $metrics ]; then
        for metric in $metrics_list; do
            base_name=\$(basename \${metric} .npy)

            # Fetch metric tag.
            stat=\$(echo "\$base_name" | cut -d'_' -f3)

            touch ${prefix}_seg-${atlas_names}_stat-\${stat}.npy
        done
    fi
    touch ${prefix_lesion}${prefix}_${atlas_names}_atlas_vol.npy
    touch ${prefix_lesion}${prefix}_${atlas_names}_atlas_sc.npy
    touch ${prefix_lesion}${prefix}_${atlas_names}_atlas_len.npy
    touch ${prefix_lesion}${prefix}_${atlas_names}_lesion_sc.npy
    touch ${prefix_lesion}${prefix}_${atlas_names}_lesion_vol.npy
    touch ${prefix_lesion}${prefix}_${atlas_names}_lesion_count.npy

    scil_connectivity_compute_matrices.py -h

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scilpy: \$(pip list | grep scilpy | tr -s ' ' | cut -d' ' -f2)
    END_VERSIONS

    """
}

