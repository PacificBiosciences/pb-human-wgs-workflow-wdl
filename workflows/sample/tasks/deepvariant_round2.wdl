version 1.0

import "../structs/BamPair.wdl"
import "./separate_data_and_index_files.wdl"

task make_examples_round2 {
  input {
    String sample_name    
    Float vsc_min_fraction_indels = "0.12"
    Array[File] bams
    Array[File] bais
    IndexedData reference
    String log_name = "make_examples_round2.log"
    String deepvariant_image

    Int threads = 64
    Int threads_m1 = threads - 1
    String tfrecord_name = "examples.tfrecord@~{threads}.gz"
    String nonvariant_site_tfrecord_name = "gvcF.tfrecord@~{threads}.gz" # temp(f"samples/{sample}/deepvariant/examples/gvcf.tfrecord-{{shard}}-of-{config['N_SHARDS']:05}.gz")
    String commands_name = "commands.txt"
  }

  command <<<
    make_examples_func="       /opt/deepvariant/bin/make_examples \
        --norealign_reads \
        --vsc_min_fraction_indels ~{vsc_min_fraction_indels} \
        --alt_aligned_pileup=diff_channels \
        --parse_sam_aux_fields \
        --sort_by_haplotypes \
        --mode calling \
        --ref ~{reference.datafile} \
        --reads ~{sep="," bams} \
        --examples ~{tfrecord_name} \
        --gvcf ~{nonvariant_site_tfrecord_name} \
        --sample_name=~{sample_name} \
        --task tn"

    for thread_num in {0..~{threads_m1}}
    do
       echo $make_examples_func | sed -e "s/tn/$thread_num/g" >> ~{commands_name}
    done

    ( parallel  --jobs ~{threads} < ~{commands_name} ) > ~{log_name} 2>&1
  >>>
  output {
    Array[File] tfrecords = glob("examples.tfrecord*.gz")
    Array[File] nonvariant_site_tfrecord = glob("gvcF.tfrecord*.gz")
    File log = "~{log_name}"
  }
  runtime {
    docker: "~{deepvariant_image}"
    preemptible: true
    maxRetries: 3
    memory: "256 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

task call_variants_round2 {
  input {
    Int threads = 64
    String model = "/opt/models/pacbio/model.ckpt"
    String log_name = "call_variants_round2.log"
    Array[File] example_tfrecord # expand(f"samples/{sample}/deepvariant/examples/examples.tfrecord-{{shard}}-of-{config['N_SHARDS']:05}.gz", shard=shards)
    String sample_name
    String? reference_name
    String call_variants_output_tfrecord_gz_name = "~{sample_name}.~{reference_name}.call_variants_output.tfrecord.gz"
    String deepvariant_image
  }

  command <<<
    tfrecords_csv=~{sep="," example_tfrecord}

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
        --outfile ~{call_variants_output_tfrecord_gz_name} \
        --examples examples.tfrecord@$total_records_formatted.gz  \
        --checkpoint ~{model}
    ) > ~{log_name} 2>&1
  >>>

  output {
    File call_variants_output_tfrecord_gz = "~{call_variants_output_tfrecord_gz_name}"
    File log = "~{log_name}"
  }
  runtime {
    docker: "~{deepvariant_image}"
    preemptible: true
    maxRetries: 3
    memory: "256 GB"
    cpu: "~{threads}"
    disk: "500 GB"
  }
}

task postprocess_variants_round2 {
  input {
    Int threads = 4
    String log_name = "postprocess_variants_round2.log"

    String sample_name
    File tfrecords 
    Array[File] nonvariant_site_tfrecords
    IndexedData reference 

    String vcf_name = "~{sample_name}.~{reference.name}.deepvariant.vcf.gz"
    String gvcf_name = "~{sample_name}.~{reference.name}.deepvariant.g.vcf.gz"
    String report_name = "~{sample_name}.~{reference.name}.deepvariant.visual_report.html"

    String deepvariant_image
  }

  command <<<
    nonvariant_site_tfrecords_csv=~{sep="," nonvariant_site_tfrecords}
    IFS=, paths=($nonvariant_site_tfrecords_csv)
    total_records=${#paths[@]}
    total_records_formatted=$(printf '%05d'  $total_records)
    for (( record_num=0; record_num<$total_records; record_num++ ))
    do
       nonvariant_site_tfrecord=$(echo "${paths[$record_num]}")
       echo $nonvariant_site_tfrecord
       record_num_formatted=$(printf '%05d'  $record_num)
       cp $nonvariant_site_tfrecord nonvariant_site-$record_num_formatted-of-$total_records_formatted.tfrecord
    done

    (
      /opt/deepvariant/bin/postprocess_variants \
        --ref ~{reference.datafile} \
        --infile ~{tfrecords} \
        --outfile ~{vcf_name} \
        --nonvariant_site_tfrecord_path nonvariant_site@$total_records_formatted.tfrecord \
        --gvcf_outfile ~{gvcf_name} \
        --sample_name=~{sample_name}
    ) > ~{log_name} 2>&1
  >>>
  output {
    File vcf_data = "~{vcf_name}"
    File vcf_index = "~{vcf_name}.tbi"
    IndexedData vcf = { "datafile": vcf_data, "indexfile": vcf_index }

    File gvcf_data = "~{gvcf_name}"
    File gvcf_index = "~{gvcf_name}.tbi"
    IndexedData gvcf = { "datafile": gvcf_data, "indexfile": gvcf_index }

    File report = "~{report_name}"

    File log = "~{log_name}"
  }
  runtime {
    docker: "~{deepvariant_image}"
    preemptible: true
    maxRetries: 3
    memory: "30 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

task bcftools_stats {
  input {
    Int threads = 4
    IndexedData reference
    String sample_name
    String params = "--fasta-ref ~{reference.datafile} --apply-filters PASS"
    String log_name = "bcftools_stats.log"
    IndexedData deepvariant_vcf_gz
    String deepvariant_vcf_stats_txt_name = "~{sample_name}.~{reference.name}.deepvariant.vcf.stats.txt"
    String pb_conda_image
  }

  command <<<
    source ~/.bashrc
    conda activate bcftools
    echo "$(conda info)"

    (bcftools stats --threads 3 ~{params} ~{deepvariant_vcf_gz.datafile} > ~{deepvariant_vcf_stats_txt_name}) > ~{log_name} 2>&1
  >>>
  output {
    File deepvariant_vcf_stats_txt = "~{deepvariant_vcf_stats_txt_name}"
    File log = "~{log_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

workflow deepvariant_round2 {
  input {
    IndexedData reference
    String sample_name
    Array[IndexedData] whatshap_bams

    String deepvariant_image
    String pb_conda_image
  }

  call separate_data_and_index_files.separate_data_and_index_files {
    input:
      indexed_data_array = whatshap_bams,
  }

  call make_examples_round2 {
    input:
      sample_name = sample_name,
      bams = separate_data_and_index_files.datafiles,
      bais = separate_data_and_index_files.indexfiles,
      reference = reference,
      deepvariant_image = deepvariant_image
  }

  call call_variants_round2 {
    input:
      sample_name = sample_name,
      reference_name = reference.name,
      example_tfrecord = make_examples_round2.tfrecords,
      deepvariant_image = deepvariant_image
  }

  call postprocess_variants_round2 {
    input:
      sample_name = sample_name,
      tfrecords = call_variants_round2.call_variants_output_tfrecord_gz,
      nonvariant_site_tfrecords = make_examples_round2.nonvariant_site_tfrecord,
      reference = reference,
      deepvariant_image = deepvariant_image
  }

  call bcftools_stats {
    input:
      sample_name = sample_name,
      reference = reference,
      deepvariant_vcf_gz = postprocess_variants_round2.vcf,
      pb_conda_image = pb_conda_image
  }

  output {
    IndexedData vcf = postprocess_variants_round2.vcf
    IndexedData gvcf = postprocess_variants_round2.gvcf
 }

}
