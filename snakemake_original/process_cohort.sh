#!/bin/bash
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task 4
#SBATCH -o cluster_logs/slurm-%x-%j-%N.out

# set umask to avoid locking each other out of directories
umask 002

COHORT=$1
mkdir -p cohorts/${COHORT}/
LOCKFILE=cohorts/${COHORT}/process_cohort.lock

# add lockfile to directory to prevent multiple simultaneous jobs
lockfile -r 0 ${LOCKFILE} || exit 1
trap "rm -f ${LOCKFILE}; exit" SIGINT SIGTERM ERR EXIT

# execute snakemake
snakemake --reason \
    --keep-going \
    --printshellcmds \
    --config cohort=${COHORT} \
    --nolock \
    --local-cores 4 \
    --jobs 500 \
    --max-jobs-per-second 1 \
    --use-conda \
    --use-singularity --singularity-args '--nv ' \
    --latency-wait 90 \
    --cluster-config workflow/process_cohort.cluster.yaml \
    --cluster "sbatch --account={cluster.account} \
                      --partition={cluster.partition} \
                      --cpus-per-task={cluster.cpus} \
                      --output={cluster.out} {cluster.extra} " \
    --snakefile workflow/process_cohort.smk
