version 1.0

import "../structs/BamPair.wdl"
import "./common_bgzip_vcf.wdl" as bgzip_vcf
import "./collect_bams_and_bais.wdl"
import "./separate_data_and_index_files.wdl"

task glnexus_task {
  input {
    String cohort_name
    String? reference_name
    Int threads = 24
    String log_name = "glnexus_task.log"

    Array[File] affected_patient_gvcfs
    Array[File] affected_patient_gvcfs_index
    Array[File] unaffected_patient_gvcfs
    Array[File] unaffected_patient_gvcfs_index

    String bcf_name = "~{cohort_name}.~{reference_name}.deepvariant.glnexus.bcf"
    String scratch_dir = "./~{cohort_name}.~{reference_name}.GLnexus.DB"

    String glnexus_image
  }

  command <<<
    (
#         rm -rf ~{scratch_dir} && \
        glnexus_cli --threads ~{threads} \
            --dir ~{scratch_dir} \
            --config DeepVariant_unfiltered ~{sep=" " affected_patient_gvcfs}  ~{sep=" " unaffected_patient_gvcfs} > ~{bcf_name}
     )  > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File bcf = "~{bcf_name}"
  }
  runtime {
    docker: "~{glnexus_image}"
    preemptible: true
    maxRetries: 3
    memory: "30 GB"
    cpu: "~{threads}"
    disk: "600 GB"
  }
}

task bcftools_bcf2vcf {
  input {
    String params = "--threads 4 -Oz"
    String bcftools_log_name = "bcftools_bcf2vcf.log"
    String tabix_log_name = "tabix.log"
    File bcf

    String vcf_gz_name = sub("~{basename(bcf)}", "bcf", "vcf.gz")

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate bcftools
    echo "$(conda info)"

    (bcftools view ~{params} ~{bcf} -o ~{vcf_gz_name}) > ~{bcftools_log_name} 2>&1

    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    (tabix ~{vcf_gz_name}) > ~{tabix_log_name} 2>&1
  >>>
  output {
    File bcftools_log = "~{bcftools_log_name}"
    File tabix_log = "~{tabix_log_name}"
    IndexedData vcf_gz = { "datafile": "~{vcf_gz_name}", "indexfile": "~{vcf_gz_name}.tbi" }
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

task split_glnexus_vcf {
  input {
    String cohort_name
    String? reference_name
    String region
    String extra = "-h"

    String log_name = "split_glnexus_vcf.log"

    IndexedData vcf

    String deepvariant_glnexus_vcf_name = "~{cohort_name}.~{reference_name}.~{region}.deepvariant.glnexus.vcf"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    (tabix ~{extra} ~{vcf.datafile} ~{region} > ~{deepvariant_glnexus_vcf_name}) 2> ~{log_name}
  >>>
  output {
    File log = "~{log_name}"
    File deepvariant_glnexus_vcf = "~{deepvariant_glnexus_vcf_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

task whatshap_phase {
  input {
    String cohort_name
    String chromosome
    String extra = "--indels"

    String whatshap_phase_log_name = "whatshap_phase.log"
    String tabix_log_name = "tabix.log"

    IndexedData reference
    IndexedData vcf
    Array[File] phaseinput_affected
    Array[File] phaseinputindex_affected
    Array[File] phaseinput_unaffected
    Array[File] phaseinputindex_unaffected

    String deepvariant_glnexus_phased_vcf_gz_name = "~{cohort_name}.~{reference.name}.~{chromosome}.deepvariant.glnexus.phased.vcf.gz"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate whatshap
    echo "$(conda info)"

    (
      whatshap phase ~{extra} \
        --chromosome ~{chromosome} \
        --output ~{deepvariant_glnexus_phased_vcf_gz_name} \
        --reference ~{reference.datafile} \
        ~{vcf.datafile} ~{sep=" " phaseinput_affected} ~{sep=" " phaseinput_unaffected}
    ) > ~{whatshap_phase_log_name} 2>&1

    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    (tabix ~{deepvariant_glnexus_phased_vcf_gz_name}) > ~{tabix_log_name} 2>&1
  >>>
  output {
    File whatshap_phase_log = "~{whatshap_phase_log_name}"
    File tabix_log = "~{tabix_log_name}"
    File deepvariant_glnexus_phased_vcf_gz = "~{deepvariant_glnexus_phased_vcf_gz_name}"
    File deepvariant_glnexus_phased_vcf_gz_tbi = "~{deepvariant_glnexus_phased_vcf_gz_name}.tbi"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

task whatshap_bcftools_concat {
  input {
    String cohort_name
    String? reference_name
    String params = "-a -Oz"
    String whatshap_bcftools_concat_log_name = "whatshap_bcftools_concat.log"
    String tabix_log_name = "tabix.log"

    Array[File] calls
    Array[File] indices

    String deepvariant_glnexus_phased_vcf_gz_name = "~{cohort_name}.~{reference_name}.deepvariant.glnexus.phased.vcf.gz"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate bcftools
    echo "$(conda info)"

    (bcftools concat ~{params} -o ~{deepvariant_glnexus_phased_vcf_gz_name} ~{sep=" " calls}) > ~{whatshap_bcftools_concat_log_name} 2>&1

    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    (tabix ~{deepvariant_glnexus_phased_vcf_gz_name}) > ~{tabix_log_name} 2>&1
  >>>
  output {
    File whatshap_bcftools_concat_log = "~{whatshap_bcftools_concat_log_name}"
    File tabix_log = "~{tabix_log_name}"
    IndexedData deepvariant_glnexus_phased_vcf_gz = { "datafile": "~{deepvariant_glnexus_phased_vcf_gz_name}", "indexfile": "~{deepvariant_glnexus_phased_vcf_gz_name}.tbi" }
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

task whatshap_stats {
  input {
    String cohort_name
    String? reference_name
    String log_name = "whatshap_stats.log"

    IndexedData vcf
    File chr_lengths

    String gtf_name = "~{cohort_name}.~{reference_name}.deepvariant.glnexus.phased.gtf"
    String tsv_name = "~{cohort_name}.~{reference_name}.deepvariant.glnexus.phased.tsv"
    String blocklist_name = "~{cohort_name}.~{reference_name}.deepvariant.glnexus.phased.blocklist"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate whatshap
    echo "$(conda info)"

    (whatshap stats \
        --gtf ~{gtf_name} \
        --tsv ~{tsv_name} \
        --block-list ~{blocklist_name} \
        --chr-lengths ~{chr_lengths} \
        ~{vcf.datafile}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File gtf = "~{gtf_name}"
    File tsv = "~{tsv_name}" 
    File blocklist = "~{blocklist_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

workflow glnexus {
  input {
    String cohort_name
    Array[IndexedData] affected_patient_gvcfs
    Array[IndexedData] unaffected_patient_gvcfs
    Array[Array[IndexedData]] affected_patient_bams
    Array[Array[IndexedData]] unaffected_patient_bams
    Array[String] regions
    IndexedData reference
    File chr_lengths

    String pb_conda_image
    String glnexus_image
  }

  call separate_data_and_index_files.separate_data_and_index_files as gather_affected_patient_gvcfs {
    input:
      indexed_data_array = affected_patient_gvcfs
  }

  call separate_data_and_index_files.separate_data_and_index_files as gather_unaffected_patient_gvcfs {
    input:
      indexed_data_array = unaffected_patient_gvcfs
  }

  call glnexus_task {
    input:
      cohort_name = cohort_name,
      reference_name = reference.name,
      affected_patient_gvcfs = gather_affected_patient_gvcfs.datafiles,
      affected_patient_gvcfs_index = gather_affected_patient_gvcfs.indexfiles,
      unaffected_patient_gvcfs = gather_unaffected_patient_gvcfs.datafiles,
      unaffected_patient_gvcfs_index = gather_unaffected_patient_gvcfs.indexfiles,
      glnexus_image = glnexus_image
  }

  call bcftools_bcf2vcf {
    input:
      bcf = glnexus_task.bcf,
      pb_conda_image = pb_conda_image
  }

  scatter(region in regions) {
    call split_glnexus_vcf {
      input:
        cohort_name = cohort_name,
        reference_name = reference.name,
        vcf = bcftools_bcf2vcf.vcf_gz,
        region = region,
        pb_conda_image = pb_conda_image
    }
  }

  scatter (region_num in range(length(regions))) {
    call bgzip_vcf.bgzip_vcf {
      input :
        vcf_input = split_glnexus_vcf.deepvariant_glnexus_vcf[region_num],
        pb_conda_image = pb_conda_image
    }
  }

  scatter (sample_bams in affected_patient_bams) {
    call separate_data_and_index_files.separate_data_and_index_files as gather_affected_patient_bams_and_bais  {
      input:
        indexed_data_array = sample_bams,
    }
  }

  scatter (sample_bams in affected_patient_bams) {
    call separate_data_and_index_files.separate_data_and_index_files as gather_unaffected_patient_bams_and_bais  {
      input:
        indexed_data_array = sample_bams,
    }
  }

  scatter (region_num in range(length(regions))) {
    call whatshap_phase {
      input:
        cohort_name = cohort_name,
        reference = reference, 
        vcf = bgzip_vcf.vcf_gz_output[region_num], 
        phaseinput_affected = flatten(gather_affected_patient_bams_and_bais.datafiles), 
        phaseinputindex_affected = flatten(gather_affected_patient_bams_and_bais.indexfiles),
        phaseinput_unaffected = flatten(gather_unaffected_patient_bams_and_bais.datafiles), 
        phaseinputindex_unaffected = flatten(gather_unaffected_patient_bams_and_bais.indexfiles),
        chromosome = regions[region_num],
        pb_conda_image = pb_conda_image
    }
  }

  call whatshap_bcftools_concat {
    input:
      cohort_name = cohort_name,
      reference_name = reference.name,
      calls = whatshap_phase.deepvariant_glnexus_phased_vcf_gz,
      indices = whatshap_phase.deepvariant_glnexus_phased_vcf_gz_tbi,
      pb_conda_image = pb_conda_image
  }

  call whatshap_stats {
    input:
      cohort_name = cohort_name,
      reference_name = reference.name,
      vcf = whatshap_bcftools_concat.deepvariant_glnexus_phased_vcf_gz,
      chr_lengths = chr_lengths,
      pb_conda_image = pb_conda_image
  }

  output {
    IndexedData deepvariant_glnexus_phased_vcf_gz = whatshap_bcftools_concat.deepvariant_glnexus_phased_vcf_gz
  }
}
