version 1.0

import "../../common/structs.wdl"

#import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

task samtools_fasta {
  input {
    String log_name = "samtools_fasta.log"

    SmrtcellInfo movie  #in new-schema

    String movie_fasta_name = "~{movie.name}.fasta"
    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25

  Int disk_size = ceil(multiplier * size(movie.path, "GB")) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate samtools
    echo "$(conda info)"

    (samtools fasta -@ 3 ~{movie.path} > ~{movie_fasta_name}) > ~{log_name} 2>&1
  >>>
  output {
    File movie_fasta = "~{movie_fasta_name}"
    File log = "~{log_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "256 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

task seqtk_fastq_to_fasta {
  input {
    SmrtcellInfo movie
    String log_name = "seqtk_fastq_to_fasta.log"
    String movie_fasta_name = "~{movie.name}.fasta"
    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(movie.path, "GB")) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate seqtk
    echo "$(conda info)"

    (seqtk seq -A ~{movie.path} > ~{movie_fasta_name}) > ~{log_name} 2>&1
  >>>
  output {
    File movie_fasta = "~{movie_fasta_name}"
    File log = "~{log_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "256 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

workflow fasta_conversion {
  input {
    SmrtcellInfo movie
    String pb_conda_image
  }

  call samtools_fasta {
      input:
        movie = movie,
        pb_conda_image = pb_conda_image
  }
  
  output {
    File movie_fasta = samtools_fasta.movie_fasta
  }
}
