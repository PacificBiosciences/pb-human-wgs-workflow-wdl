version 1.0

#import "../../common/structs.wdl"
#import "../../common/separate_data_and_index_files.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/separate_data_and_index_files.wdl"

task make_examples_round1 {
  input {
    String sample_name    
    Float vsc_min_fraction_indels = "0.12"
    Array[File] bams
    Array[File] bais
    IndexedData reference
    String log_name = "make_examples_round1.log"
    String deepvariant_image
    Int pileup_image_width = 199

    Int threads = 64
    Int threads_m1 = threads - 1
    String tfrecord_name = "examples.tfrecord@~{threads}.gz"
    String commands_name = "commands.txt"
  }

#  Float multiplier = 3.25
#  Int disk_size = ceil(multiplier * (size(reference.datafile, "GB") + size(reference.indexfile, "GB") + size(bams, "GB") + size(bais, "GB"))) + 20
  Int disk_size = 500

  command <<<
    echo requested disk_size =  ~{disk_size}

    make_examples_func="     /opt/deepvariant/bin/make_examples \
        --norealign_reads \
        --pileup_image_width ~{pileup_image_width}
        --vsc_min_fraction_indels ~{vsc_min_fraction_indels} \
        --alt_aligned_pileup=diff_channels \
        --add_hp_channel \
        --sort_by_haplotypes \
        --parse_sam_aux_fields \
        --mode calling \
        --ref ~{reference.datafile} \
        --reads ~{sep="," bams} \
        --examples ~{tfrecord_name} \
        --sample_name=~{sample_name} \
        --task tn
    "

    for thread_num in {0..~{threads_m1}}
    do
       echo $make_examples_func | sed -e "s/tn/$thread_num/g" >> ~{commands_name}
    done

    ( parallel  --jobs ~{threads} < ~{commands_name} ) > ~{log_name} 2>&1
  >>>
  output {
    Array[File] tfrecords = glob("examples.tfrecord*.gz")
    File log = "~{log_name}"
    File commands = "~{commands_name}"
  }
  runtime {
    docker: "~{deepvariant_image}"
    preemptible: true
    maxRetries: 3
    memory: "256 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

task call_variants_round1 {
  input {
    Int threads = 64
    String model = "/opt/models/pacbio/model.ckpt"
    String log_name = "call_variants_round1.log"
    String sample_name
    String? reference_name
    String tfrecord_output_name = "~{sample_name}.~{reference_name}.call_variants_output.tfrecord.gz"

    Array[File] tfrecord_input
    String deepvariant_image
  }

#  Float multiplier = 3.25
#  Int disk_size = ceil(multiplier * size(tfrecord_input, "GB")) + 20
  Int disk_size = 500

  command <<<
    echo requested disk_size =  ~{disk_size}

    tfrecords_csv=~{sep="," tfrecord_input}

    IFS=, paths=($tfrecords_csv)
    total_records=${#paths[@]}
    total_records_formatted=$(printf '%05d'  $total_records)
    for (( record_num=0; record_num<$total_records; record_num++ ))
    do
       tfrecord=$(echo "${paths[$record_num]}")
       echo $tfrecord
       record_num_formatted=$(printf '%05d'  $record_num)
       cp $tfrecord examples.tfrecord-$record_num_formatted-of-$total_records_formatted.gz
       echo examples.tfrecord-$record_num_formatted-of-$total_records_formatted.gz
    done
    
    (
      /opt/deepvariant/bin/call_variants \
        --outfile ~{tfrecord_output_name} \
        --examples examples.tfrecord@$total_records_formatted.gz  \
        --checkpoint ~{model}
    ) > ~{log_name} 2>&1
  >>>
  output {
    File tfrecord_output = "~{tfrecord_output_name}"
    File log = "~{log_name}"
  }
  runtime {
    docker: "~{deepvariant_image}"
    preemptible: true
    maxRetries: 3
    memory: "256 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

task postprocess_variants_round1 {
  input {
    Int threads = 4
    String log_name = "postprocess_variants_round1.log"
    String sample_name
    File tfrecords
    IndexedData reference
    String vcf_name = "~{sample_name}.~{reference.name}.deepvariant.vcf.gz"
    String report_name = "~{sample_name}.~{reference.name}.deepvariant.visual_report.html"

    String deepvariant_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(reference.datafile, "GB") + size(reference.indexfile, "GB") + size(tfrecords, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}

    (
      /opt/deepvariant/bin/postprocess_variants \
        --ref ~{reference.datafile} \
        --infile ~{tfrecords} \
        --outfile ~{vcf_name} \
        --sample_name=~{sample_name}
    ) > ~{log_name} 2>&1
  >>>
  output {
    File vcf_data = "~{vcf_name}"
    File vcf_index = "~{vcf_name}.tbi"
    IndexedData vcf = { "datafile": vcf_data, "indexfile": vcf_index }

    File report = "~{report_name}"
    File log = "~{log_name}"
  }
  runtime {
    docker: "~{deepvariant_image}"
    preemptible: true
    maxRetries: 3
    memory: "30 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

workflow deepvariant_round1 {
  input {
    IndexedData reference
    String sample_name
    Array[IndexedData] sample

    String deepvariant_image
  }

  call separate_data_and_index_files.separate_data_and_index_files {
    input:
      indexed_data_array = sample,
  }

  call make_examples_round1 {
    input:
      sample_name = sample_name,
      bams = separate_data_and_index_files.datafiles,
      bais = separate_data_and_index_files.indexfiles,
      reference = reference,
      deepvariant_image = deepvariant_image
  }

  call call_variants_round1 {
    input:
      sample_name = sample_name,
      reference_name = reference.name,
      tfrecord_input = make_examples_round1.tfrecords,
      deepvariant_image = deepvariant_image
  }

  call postprocess_variants_round1 {
    input:
      sample_name = sample_name,
      tfrecords = call_variants_round1.tfrecord_output,
      reference = reference,
      deepvariant_image = deepvariant_image
  }

  output {
    IndexedData postprocess_variants_round1_vcf = postprocess_variants_round1.vcf
  }

}
