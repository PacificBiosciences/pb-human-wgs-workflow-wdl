version 1.0

#import "../../common/structs.wdl"
#import "./common.wdl" as common
#import "./samtools_index_bam.wdl" as samtools_common
#import "../../common/separate_data_and_index_files.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/common.wdl" as common
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/samtools_index_bam.wdl" as samtools_common
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/separate_data_and_index_files.wdl"

task split_deepvariant_vcf_round1 {
  input {
    String sample_name
    String? reference_name
    String region
    String extra = "-h"
    String log_name = "deepvariant_intermediate_vcf_round1.log"

    IndexedData deepvariant_vcf_gz
    String deepvariant_vcf_name = "~{sample_name}.~{reference_name}.~{region}.deepvariant.vcf"
    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(deepvariant_vcf_gz.datafile, "GB") + size(deepvariant_vcf_gz.indexfile, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    tabix ~{extra} ~{deepvariant_vcf_gz.datafile} ~{region} > ~{deepvariant_vcf_name} 2> ~{log_name}
  >>>
  output {
    File deepvariant_vcf = "~{deepvariant_vcf_name}"
    File log = "~{log_name}"
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

task whatshap_phase_round1 {
  input {
    String sample_name
    String chromosome
    String whatshap_phase_log_name = "whatshap_phase_round1.log"
    String tabix_log_name = "tabix.log"

    IndexedData reference
    IndexedData vcf
    Array[File] phaseinput
    Array[File] phaseinputindex

    String deepvariant_phased_vcf_gz_name = "~{sample_name}.~{reference.name}.~{chromosome}.deepvariant.phased.vcf.gz"
    String pb_conda_image
    Int threads = 32
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(reference.datafile, "GB") + size(reference.indexfile, "GB") + size(vcf.datafile, "GB") + size(vcf.indexfile, "GB") + size(phaseinput, "GB") + size(phaseinputindex, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate whatshap
    echo "$(conda info)"

    (whatshap phase \
        --chromosome ~{chromosome} \
        --output ~{deepvariant_phased_vcf_gz_name} \
        --reference ~{reference.datafile} \
        ~{vcf.datafile} ~{sep=" " phaseinput}) > ~{whatshap_phase_log_name} 2>&1

    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    (tabix ~{deepvariant_phased_vcf_gz_name}) > ~{tabix_log_name} 2>&1
  >>>
  output {
    File deepvariant_phased_vcf_gz_data = "~{deepvariant_phased_vcf_gz_name}"
    File deepvariant_phased_vcf_gz_index = "~{deepvariant_phased_vcf_gz_name}.tbi"
    IndexedData deepvariant_phased_vcf_gz = { "datafile": deepvariant_phased_vcf_gz_data, "indexfile": deepvariant_phased_vcf_gz_index }

    File whatshap_phase_log = "~{whatshap_phase_log_name}"
    File tabix_log = "~{tabix_log_name}"
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

task whatshap_bcftools_concat_round1 {
  input {
    String sample_name
    String? reference_name
    String params = "-a -Oz"
    String bcftools_concat_log_name = "bcftools_concat_round1.log"
    String tabix_log_name = "tabix.log"

    Array[File] calls
    Array[File] indices

    String deepvariant_phased_vcf_gz_name = "~{sample_name}.~{reference_name}.deepvariant.phased.vcf.gz"
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

    bcftools concat ~{params} -o ~{deepvariant_phased_vcf_gz_name} ~{sep=" " calls} > ~{bcftools_concat_log_name} 2>&1

    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    (tabix ~{deepvariant_phased_vcf_gz_name}) > ~{tabix_log_name} 2>&1
  >>>
  output {
    File deepvariant_phased_vcf_gz_data = "~{deepvariant_phased_vcf_gz_name}"
    File deepvariant_phased_vcf_gz_index = "~{deepvariant_phased_vcf_gz_name}.tbi"
    IndexedData deepvariant_phased_vcf_gz = { "datafile": deepvariant_phased_vcf_gz_data, "indexfile": deepvariant_phased_vcf_gz_index }

    File bcftools_concat_log = "~{bcftools_concat_log_name}"
    File tabix_log = "~{tabix_log_name}"
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

task whatshap_haplotag_round1 {
  input {
    String params = "--tag-supplementary"
    String log_name = "whatshap_haplotag_round1.log"

    IndexedData reference
    IndexedData vcf
    IndexedData smrtcell

    String sample_name

    String deepvariant_haplotagged_bam_name = "~{sample_name}.~{reference.name}.~{smrtcell.name}.deepvariant.haplotagged.bam"
    String pb_conda_image
    Int threads = 8
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(reference.datafile, "GB") + size(reference.indexfile, "GB") + size(vcf.datafile, "GB") + size(vcf.indexfile, "GB") + size(smrtcell.datafile, "GB") + size(smrtcell.indexfile, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate whatshap
    echo "$(conda info)"

    (whatshap haplotag ~{params} \
        --output ~{deepvariant_haplotagged_bam_name} \
        --reference ~{reference.datafile} \
        ~{vcf.datafile} ~{smrtcell.datafile}) > ~{log_name} 2>&1
  >>>
  output {
    File deepvariant_haplotagged_bam = "~{deepvariant_haplotagged_bam_name}"
    File log = "~{log_name}"
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

workflow whatshap_round1 {
  input {
    IndexedData deepvariant_vcf_gz
    IndexedData reference
    String sample_name
    Array[IndexedData] sample
    Array[String] regions
    String pb_conda_image
  }

  scatter (region in regions) {
    call split_deepvariant_vcf_round1 {
      input:
        sample_name = sample_name,
        reference_name = reference.name,
        deepvariant_vcf_gz = deepvariant_vcf_gz,
        region = region,
        pb_conda_image = pb_conda_image
    }
  }

  scatter(deepvariant_vcf in split_deepvariant_vcf_round1.deepvariant_vcf) {
    call common.common {
      input :
        vcf_input = deepvariant_vcf,
        pb_conda_image = pb_conda_image
    }
  }

  call separate_data_and_index_files.separate_data_and_index_files as whatshap_phase_phaseinput {
    input:
      indexed_data_array = sample,
  }

  scatter (region_num in range(length(regions))) {
    call whatshap_phase_round1 {
      input:
        sample_name = sample_name,
        reference = reference,
        vcf = common.vcf_gz[region_num],
        phaseinput = whatshap_phase_phaseinput.datafiles,
        phaseinputindex = whatshap_phase_phaseinput.indexfiles,
        chromosome = regions[region_num],
        pb_conda_image = pb_conda_image
    }
  }

  call separate_data_and_index_files.separate_data_and_index_files as whatshap_phased_gvcf {
    input:
      indexed_data_array = whatshap_phase_round1.deepvariant_phased_vcf_gz,
  }

  call whatshap_bcftools_concat_round1 {
    input:
      sample_name = sample_name,
      reference_name = reference.name,
      calls = whatshap_phased_gvcf.datafiles,
      indices = whatshap_phased_gvcf.indexfiles,
      pb_conda_image = pb_conda_image
  }

  scatter(smtrcell_num in range(length(sample))) {
    call whatshap_haplotag_round1 {
      input:
        reference = reference,
        vcf = whatshap_bcftools_concat_round1.deepvariant_phased_vcf_gz,
        sample_name = sample_name,
        smrtcell = sample[smtrcell_num],
        pb_conda_image = pb_conda_image
    }
  }

  scatter(smtrcell_num in range(length(sample))) {
    call samtools_common.samtools_index_bam as deepvariant_haplotagged_bam_indexing {
      input:
        bam_datafile = whatshap_haplotag_round1.deepvariant_haplotagged_bam[smtrcell_num],
        pb_conda_image = pb_conda_image
    }
  }

  output {
     Array[IndexedData] whatshap_bams = deepvariant_haplotagged_bam_indexing.bam
  }
}