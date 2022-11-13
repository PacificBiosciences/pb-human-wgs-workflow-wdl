version 1.0

import "../../common/structs.wdl"
import "./common_bgzip_vcf.wdl" as bgzip_vcf
import "../../common/separate_data_and_index_files.wdl"

task glnexus_task {
  input {
    String cohort_name
    String? reference_name
    Int threads = 24
    String log_name = "glnexus_task.log"

    Array[File] person_gvcfs
    Array[File] person_gvcfs_index

    String bcf_name = "~{cohort_name}.~{reference_name}.deepvariant.glnexus.bcf"
    String scratch_dir = "./~{cohort_name}.~{reference_name}.GLnexus.DB"

    String glnexus_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(person_gvcfs, "GB") + size(person_gvcfs_index, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}

    (
        glnexus_cli --threads ~{threads} \
            --dir ~{scratch_dir} \
            --config DeepVariant_unfiltered ~{sep=" " person_gvcfs}  > ~{bcf_name}
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
    disk: disk_size + " GB"
  }
}

task bcftools_bcf2vcf {
  input {
    Int threads = 4
    String params = "--threads ~{threads} -Oz"
    String bcftools_log_name = "bcftools_bcf2vcf.log"
    String tabix_log_name = "tabix.log"
    File bcf

    String vcf_gz_name = sub("~{basename(bcf)}", "bcf", "vcf.gz")

    String pb_conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(bcf, "GB")) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
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
    disk: disk_size + " GB"
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

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(vcf.datafile, "GB") + size(vcf.indexfile, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
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
    disk: disk_size + " GB"
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
    Array[File] phaseinput
    Array[File] phaseinputindex

    String deepvariant_glnexus_phased_vcf_gz_name = "~{cohort_name}.~{reference.name}.~{chromosome}.deepvariant.glnexus.phased.vcf.gz"

    String pb_conda_image
    Int threads = 2
  }

   Float multiplier = 3.25
   Int disk_size = ceil(multiplier * (size(phaseinput, "GB") + size(phaseinputindex, "GB"))) + 20
  #Int disk_size = 500

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate whatshap
    echo "$(conda info)"

    (
      whatshap phase ~{extra} \
        --chromosome ~{chromosome} \
        --output ~{deepvariant_glnexus_phased_vcf_gz_name} \
        --reference ~{reference.datafile} \
        ~{vcf.datafile} ~{sep=" " phaseinput} 
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
    memory: "16 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
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

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(calls, "GB") + size(indices, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
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
    disk: disk_size + " GB"
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

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(vcf.datafile, "GB") + size(vcf.indexfile, "GB") + size(chr_lengths, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
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
    disk: disk_size + " GB"
  }
}

workflow glnexus {
  input {
    String cohort_name
    Array[IndexedData] person_gvcfs
    Array[Array[IndexedData]] person_bams
    Array[String] regions
    IndexedData reference
    File chr_lengths

    String pb_conda_image
    String glnexus_image
  }

  call separate_data_and_index_files.separate_data_and_index_files as gather_person_gvcfs {
    input:
      indexed_data_array = person_gvcfs
  }

  call glnexus_task {
    input:
      cohort_name = cohort_name,
      reference_name = reference.name,
      person_gvcfs = gather_person_gvcfs.datafiles,
      person_gvcfs_index = gather_person_gvcfs.indexfiles,
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

  scatter (sample_bams in person_bams) {
    call separate_data_and_index_files.separate_data_and_index_files as gather_person_bams_and_bais  {
      input:
        indexed_data_array = sample_bams
    }
  }

  scatter (region_num in range(length(regions))) {
    call whatshap_phase {
      input:
        cohort_name = cohort_name,
        reference = reference,
        vcf = bgzip_vcf.vcf_gz_output[region_num],
        phaseinput = flatten(gather_person_bams_and_bais.datafiles),
        phaseinputindex = flatten(gather_person_bams_and_bais.indexfiles),
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
