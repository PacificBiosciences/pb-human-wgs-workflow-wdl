version 1.0

#import "../../common/structs.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

task stats_ubam_or_fastq {
  input {
    SmrtcellInfo smrtcell_info

    String log_name = "stats_ubam_or_fastq.log"
    String read_length_and_quality_filename = "~{smrtcell_info.name}.read_length_and_quality.tsv"
    Int threads = 4
    String pb_conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(smrtcell_info.path, "GB")) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate smrtcell_stats
    echo "$(conda info)"

    (python3 /opt/pb/scripts/extract_read_length_and_qual.py ~{smrtcell_info.path} > ~{read_length_and_quality_filename}) > ~{log_name} 2>&1
  >>>
  output {
    File read_length_and_quality = "~{read_length_and_quality_filename}"
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

task summary_stats {
  input {
    SmrtcellInfo smrtcell_info

    String log_name1 = "summary_stats1.log"
    String log_name2 = "summary_stats2.log"
    String read_length_summary_name = "~{smrtcell_info.name}.read_length_summary.tsv"
    String read_quality_summary_name = "~{smrtcell_info.name}.read_quality_summary.tsv"

    File read_length_and_quality
    Int threads = 4
    String pb_conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(smrtcell_info.path, "GB") + size(read_length_and_quality, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate smrtcell_stats
    echo "$(conda info)"

   (awk '{b=int($2/1000); b=(b>39?39:b); print 1000*b}' "\t" $2;  ~{read_length_and_quality} |
        sort -k1,1g | datamash -g 1 count 1 sum 2 |
        awk 'BEGIN { for(i=0;i<=39;i++) { print 1000*i"\t0\t0"; } } { print; }' |
        sort -k1,1g | datamash -g 1 sum 2 sum 3 > ~{read_length_summary_name}) 2> ~{log_name1}

    (awk '{ print ($3>50?50:$3) "\t" $2; }' ~{read_length_and_quality} |
        sort -k1,1g | datamash -g 1 count 1 sum 2 |
        awk 'BEGIN { for(i=0;i<=60;i++) { print i"\t0\t0"; } } { print; }' |
        sort -k1,1g | datamash -g 1 sum 2 sum 3 > ~{read_quality_summary_name}) 2>> ~{log_name2}

  >>>
  output {
    File read_length_summary = "~{read_length_summary_name}"
    File read_quality_summary = "~{read_quality_summary_name}"
    File log1 = "~{log_name1}"
    File log2 = "~{log_name2}"
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

workflow stats {
  input {
    SmrtcellInfo smrtcell_info
    String pb_conda_image
  }

  call stats_ubam_or_fastq {
    input:
      smrtcell_info = smrtcell_info,
      pb_conda_image = pb_conda_image
  }

  call summary_stats {
    input:
      smrtcell_info = smrtcell_info,
      read_length_and_quality = stats_ubam_or_fastq.read_length_and_quality,
      pb_conda_image = pb_conda_image
  }

  output {
    File read_length_and_quality = stats_ubam_or_fastq.read_length_and_quality
    File read_length_summary = summary_stats.read_length_summary
    File read_quality_summary = summary_stats.read_length_summary
  }
}
