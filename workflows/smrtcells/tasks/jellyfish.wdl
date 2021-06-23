version 1.0

import "../../common/structs.wdl"

task samtools_fasta {
  input {
    SmrtcellInfo smrtcell_info
    Int threads = 4
    String log_name = "samtools_fasta.log"
    String jellyfish_fasta_name = "~{smrtcell_info.name}.jellyfish.fasta"
    String pb_conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(smrtcell_info.path, "GB")) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate samtools
    echo "$(conda info)"

    (samtools fasta -@ 3 ~{smrtcell_info.path} > ~{jellyfish_fasta_name}) > ~{log_name} 2>&1
  >>>
  output {
    File jellyfish_fasta = "~{jellyfish_fasta_name}"
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

task seqtk_fastq_to_fasta {
  input {
    SmrtcellInfo smrtcell_info
    String log_name = "seqtk_fastq_to_fasta.log"
    String jellyfish_fasta_name = "~{smrtcell_info.name}.jellyfish.fasta"
    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(smrtcell_info.path, "GB")) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate seqtk
    echo "$(conda info)"

    (seqtk seq -A ~{smrtcell_info.path} > ~{jellyfish_fasta_name}) > ~{log_name} 2>&1
  >>>
  output {
    File jellyfish_fasta = "~{jellyfish_fasta_name}"
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

task jellyfish_count {
  input {
    SmrtcellInfo smrtcell_info
    File? jellyfish_fasta
    Int kmer_length
    Int size = 1000000000
    String extra = "--canonical"
    Int threads = 24
    String log_name = "jellyfish_count.log"
    String count_jf_name = "~{smrtcell_info.name}.count.jf"
    String pb_conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(smrtcell_info.path, "GB") + size(jellyfish_fasta, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate jellyfish
    echo "$(conda info)"

    (jellyfish count ~{extra} \
       --mer-len=~{kmer_length} \
        --size=~{size} \
        --threads=~{threads} \
        --output=~{count_jf_name} \
        ~{jellyfish_fasta}) > ~{log_name} 2>&1

  >>>
  output {
    File count_jf = "~{count_jf_name}"
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

task dump_modimers {
  input {
    SmrtcellInfo smrtcell_info
    File count_jf
    Int threads = 2
    String log_name = "dump_modimers.log"
    String modimers_tsv_name = "~{smrtcell_info.name}.modimers.tsv.gz"
    String pb_conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(smrtcell_info.path, "GB") + size(count_jf, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate jellyfish
    echo "$(conda info)"

    (jellyfish dump -c -t ~{count_jf} \
        | PYTHONHASHSEED=0 python /opt/pb/scripts/modimer.py -N 5003 /dev/stdin \
        | sort | gzip > ~{modimers_tsv_name}) > ~{log_name} 2>&1
  >>>
  output {
    File modimers_tsv = "~{modimers_tsv_name}"
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

workflow jellyfish {
  input {
    SmrtcellInfo smrtcell_info
    Int kmer_length
    String pb_conda_image
  }

  if (smrtcell_info.isUbam)
  {
    call samtools_fasta {
      input:
        smrtcell_info = smrtcell_info,
        pb_conda_image = pb_conda_image
    }
  }

  if (!smrtcell_info.isUbam)
  {
    call seqtk_fastq_to_fasta {
      input:
        smrtcell_info = smrtcell_info,
        pb_conda_image = pb_conda_image
    }
  }

  call jellyfish_count {
    input:
      smrtcell_info = smrtcell_info,
      kmer_length = kmer_length,
      jellyfish_fasta = if smrtcell_info.isUbam then samtools_fasta.jellyfish_fasta else seqtk_fastq_to_fasta.jellyfish_fasta,
      pb_conda_image = pb_conda_image
  }

  call dump_modimers {
    input:
      smrtcell_info = smrtcell_info,
      count_jf = jellyfish_count.count_jf,
      pb_conda_image = pb_conda_image
  }

  output {
    File count_jf = jellyfish_count.count_jf
  }
}
