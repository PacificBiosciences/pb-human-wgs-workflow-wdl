version 1.0

#import "../../common/structs.wdl"
#import "./common.wdl" as common
#import "./samtools_index_bam.wdl" as samtools_common
#import "../../common/separate_data_and_index_files.wdl"

import "https://raw.githubusercontent.com/vsmalladi/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/vsmalladi/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/common.wdl" as common
import "https://raw.githubusercontent.com/vsmalladi/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/samtools_index_bam.wdl" as samtools_common
import "https://raw.githubusercontent.com/vsmalladi/pb-human-wgs-workflow-wdl/main/workflows/common/separate_data_and_index_files.wdl"

task split_deepvariant_vcf_round2 {
  input {
    String region
    String extra = '-h'

    String log_name = "deepvariant_vcf_round2.log"
    IndexedData deepvariant_vcf_gz
    String sample_name
    String? reference_name

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

task whatshap_phase_round2 {
  input {
    String chromosome
    String extra = "--indels"
    String whatshap_phase_log_name = "whatshap_phase_round2.log"
    String tabix_log_name = "tabix.log"

    IndexedData reference
    IndexedData vcf
    Array[File] phaseinput
    Array[File] phaseinputindex

    String sample_name

    String deepvariant_phased_vcf_gz_name =  "~{sample_name}.~{reference.name}.~{chromosome}.deepvariant.phased.vcf.gz"

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

    (whatshap phase ~{extra} \
        --chromosome ~{chromosome} \
        --output ~{deepvariant_phased_vcf_gz_name} \
        --reference ~{reference.datafile} \
        ~{vcf.datafile} \
        ~{sep=" " phaseinput}) > ~{whatshap_phase_log_name} 2>&1

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
    disk: disk_size + " GB"
  }
}

task whatshap_bcftools_concat_round2 {
  input {
    String params = "-a -Oz"
    String bcftools_concat_log_name = "bcftools_concat_round2.log"
    String tabix_log_name = "tabix.log"

    Array[File] calls
    Array[File] indices

    String sample_name
    String? reference_name

    String deepvariant_phased_vcf_gz_name = "~{sample_name}.~{reference_name}.deepvariant.phased.vcf.gz"

    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(calls, "GB")+ size(indices, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate bcftools
    echo "$(conda info)"

    bcftools concat ~{params} -o ~{deepvariant_phased_vcf_gz_name} ~{sep = " " calls} > ~{bcftools_concat_log_name} 2>&1

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

task whatshap_stats {
  input {
    String log_name = "whatshap_stats.log"

    IndexedData vcf
    File chr_lengths

    String sample_name
    String? reference_name

    String gtf_name = "~{sample_name}.~{reference_name}.deepvariant.phased.gtf"
    String tsv_name = "~{sample_name}.~{reference_name}.deepvariant.phased.tsv"
    String blocklist_name = "~{sample_name}.~{reference_name}.deepvariant.phased.blocklist"

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
    File gtf = "~{gtf_name}"
    File tsv = "~{tsv_name}"
    File blocklist = "~{blocklist_name}"

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

task whatshap_haplotag_round2 {
  input {
    String params = "--tag-supplementary --ignore-read-groups"
    String log_name = "whatshap_haplotag_round2.log"

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
    memory: "30 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

task merge_haplotagged_bams {
  input {
    String log_name = "haplotag.log"
    Array[File] deepvariant_haplotagged_bams
    Array[File] deepvariant_haplotagged_bais

    String sample_name
    String? reference_name

    String merged_deepvariant_haplotagged_bam_name = "~{sample_name}.~{reference_name}.deepvariant.haplotagged.bam"
    String pb_conda_image
    Int threads = 8
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(deepvariant_haplotagged_bams, "GB") + size(deepvariant_haplotagged_bais, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate samtools
    echo "$(conda info)"

    (samtools merge -@ ~{threads}-1 ~{merged_deepvariant_haplotagged_bam_name} ~{sep=" " deepvariant_haplotagged_bams}) > ~{log_name} 2>&1
  >>>
  output {
    File merged_deepvariant_haplotagged_bam = "~{merged_deepvariant_haplotagged_bam_name}"
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

workflow whatshap_round2 {
  input {
    IndexedData deepvariant_vcf_gz
    IndexedData reference
    String sample_name
    Array[IndexedData] sample

    File chr_lengths
    Array[String] regions
    String pb_conda_image
  }

    scatter (region in regions) {
      call split_deepvariant_vcf_round2 {
        input:
          deepvariant_vcf_gz = deepvariant_vcf_gz,
          region = region,
          sample_name = sample_name,
          reference_name = reference.name,
          pb_conda_image = pb_conda_image
      }
    }

  scatter(deepvariant_vcf in split_deepvariant_vcf_round2.deepvariant_vcf) {
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
    call whatshap_phase_round2 {
      input:
        reference = reference,
        vcf = common.vcf_gz[region_num],
        phaseinput = whatshap_phase_phaseinput.datafiles,
        phaseinputindex = whatshap_phase_phaseinput.indexfiles,
        chromosome = regions[region_num],
        sample_name = sample_name,
        pb_conda_image = pb_conda_image
    }
  }

  call separate_data_and_index_files.separate_data_and_index_files as whatshap_phased_gvcf {
    input:
      indexed_data_array = whatshap_phase_round2.deepvariant_phased_vcf_gz,
  }

  call whatshap_bcftools_concat_round2 {
    input:
      calls = whatshap_phased_gvcf.datafiles,
      indices = whatshap_phased_gvcf.indexfiles,
      sample_name = sample_name,
      reference_name = reference.name,
      pb_conda_image = pb_conda_image
  }


  call whatshap_stats {
    input:
      vcf = whatshap_bcftools_concat_round2.deepvariant_phased_vcf_gz,
      chr_lengths = chr_lengths,
      sample_name = sample_name,
      reference_name = reference.name,
      pb_conda_image = pb_conda_image
  }

  scatter(smtrcell_num in range(length(sample))) {
    call whatshap_haplotag_round2 {
      input:
        reference = reference,
        vcf = whatshap_bcftools_concat_round2.deepvariant_phased_vcf_gz,
        smrtcell = sample[smtrcell_num],
        sample_name = sample_name,
        pb_conda_image = pb_conda_image
    }
  }

  scatter(smtrcell_num in range(length(sample))) {
    call samtools_common.samtools_index_bam as deepvariant_haplotagged_bam_indexing {
      input:
        bam_datafile = whatshap_haplotag_round2.deepvariant_haplotagged_bam[smtrcell_num],
        pb_conda_image = pb_conda_image
    }
  }

  call separate_data_and_index_files.separate_data_and_index_files as deepvariant_haplotagged_bam_data_and_index_files {
    input:
      indexed_data_array = deepvariant_haplotagged_bam_indexing.bam
  }

  call merge_haplotagged_bams {
    input:
      sample_name = sample_name,
      reference_name = reference.name,
      deepvariant_haplotagged_bams = deepvariant_haplotagged_bam_data_and_index_files.datafiles,
      deepvariant_haplotagged_bais = deepvariant_haplotagged_bam_data_and_index_files.indexfiles,
      pb_conda_image = pb_conda_image
  }

  call samtools_common.samtools_index_bam as merge_haplotagged_bams_indexing {
    input:
      bam_datafile = merge_haplotagged_bams.merged_deepvariant_haplotagged_bam,
      pb_conda_image = pb_conda_image
  }

  output {
    IndexedData deepvariant_haplotagged = merge_haplotagged_bams_indexing.bam
    IndexedData deepvariant_phased_vcf_gz = whatshap_bcftools_concat_round2.deepvariant_phased_vcf_gz
  }
}
