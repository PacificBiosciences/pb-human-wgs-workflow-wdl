version 1.0

#import "../../common/structs.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

task samtools_fasta {
  input {
    String log_name = "samtools_fasta.log"
    IndexedData movie

    String movie_fasta_name = "~{movie.name}.fasta"
    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(movie.datafile, "GB") + size(movie.indexfile, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate samtools
    echo "$(conda info)"

    (samtools fasta -@ 3 ~{movie.datafile} > ~{movie_fasta_name}) > ~{log_name} 2>&1
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

task hifiasm_assemble {
  input {
    Int threads = 48
    String sample_name
    String prefix = "~{sample_name}.asm"
    String log_name = "hifiasm.log"

    Array[File] movie_fasta
    String pb_conda_image
  }

  Float multiplier = 2
  Int disk_size = ceil(multiplier * size(movie_fasta, "GB")) + 20
#  Int disk_size = 200
  Int memory = threads * 3              #forces at least 3GB RAM/core, even if user overwrites threads

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate hifiasm
    echo "$(conda info)"

    (hifiasm -o ~{prefix} -t ~{threads} ~{sep=" " movie_fasta}) > ~{log_name} 2>&1
  >>>
  output {
    File a_ctg        = "~{prefix}.a_ctg.gfa"
    File a_ctg_noseq  = "~{prefix}.a_ctg.noseq.gfa"
    File p_ctg        = "~{prefix}.p_ctg.gfa"
    File p_ctg_noseq  = "~{prefix}.p_ctg.noseq.gfa"
    File p_utg        = "~{prefix}.p_utg.gfa"
    File p_utg_noseq  = "~{prefix}.p_utg.noseq.gfa"
    File r_utg        = "~{prefix}.r_utg.gfa"
    File r_utg_noseq  = "~{prefix}.r_utg.noseq.gfa"
    File ec_bin       = "~{prefix}.ec.bin"
    File ovlp_rev_bin = "~{prefix}.ovlp.reverse.bin"
    File ovlp_src_bin = "~{prefix}.ovlp.source.bin"

    File log = "~{log_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "~{memory}" + " GB"                   
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}

task gfa2fa {
  input {
    String log_name = "gfa2fa.log"
    File gfa
    String fasta_name = "~{basename(gfa)}.fasta"
    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(gfa, "GB")) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate gfatools
    echo "$(conda info)"

    (gfatools gfa2fa ~{gfa} > ~{fasta_name}) 2> ~{log_name}
  >>>
  output {
    File fasta = "~{fasta_name}"
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

task bgzip_fasta {
  input {
    Int threads = 4
    String log_name = "bgzip_fasta.log"
    File fasta
    String fasta_gz_name = "~{basename(fasta)}.gz"
    String pb_conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(fasta, "GB")) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    (bgzip --threads ~{threads} ~{fasta} -c > ~{fasta_gz_name}) > ~{log_name} 2>&1
  >>>

  output {
    File fasta_gz = "~{fasta_gz_name}"
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

task asm_stats {
  input {
    String log_name = "asm_stats.log"
    File fasta_gz
    File index

    String fasta_stats_txt_name = "~{basename(fasta_gz)}.stats.txt"
    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(fasta_gz, "GB") + size(index, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate k8
    echo "$(conda info)"

    (k8 /opt/pb/scripts/calN50.js -f ~{index} ~{fasta_gz} > ~{fasta_stats_txt_name}) > ~{log_name} 2>&1
  >>>
  output {
    File fasta_stats_txt = "~{fasta_stats_txt_name}"
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

task align_hifiasm {
  input {
    String sample_name
    String reference_name
    
    Int max_chunk = 200000
    String minimap2_args = "-L --secondary=no --eqx -ax asm5"
    Int minimap2_threads = 10
    Int samtools_threads = 3

    String log_name = "align_hifiasm.log"
    IndexedData target 
    Array[File] query

    String asm_bam_name = "~{sample_name}.asm.~{reference_name}.bam"
    String pb_conda_image
    Int threads = 16
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(target.datafile, "GB") + size(target.indexfile, "GB") + size(query, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate align_hifiasm
    echo "$(conda info)"

    (cat ~{sep=" " query} \
        | seqtk seq -l ~{max_chunk} - \
        | awk '{{ if ($1 ~ />/) {{ n=$1; i=0; }} else {{ i++; print n "." i; print $0; }} }}' \
        | minimap2 -t ~{minimap2_threads} ~{minimap2_args} ~{target.datafile} - \
            | awk '{{ if ($1 !~ /^@/) \
                            {{ Rct=split($1,R,"."); N=R[1]; for(i=2;i<Rct;i++) {{ N=N"."R[i]; }} print $0 "\tTG:Z:" N; }} \
                            else {{ print; }} }}' \
            | samtools sort -@ ~{samtools_threads} > ~{asm_bam_name} \
            && samtools index -@ ~{samtools_threads} ~{asm_bam_name}) > ~{log_name} 2>&1
  >>>
  output {
    File asm_bam = "~{asm_bam_name}"
    File asm_bai = "~{asm_bam_name}.bai"
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


workflow hifiasm {
  input {
    String sample_name
    Array[IndexedData] sample
    IndexedData target
    String pb_conda_image
  }

  scatter (movie in sample) {
    call samtools_fasta {
      input:
        movie = movie,
        pb_conda_image = pb_conda_image
    }
  }

  call hifiasm_assemble {
    input:
      sample_name = sample_name,
      movie_fasta = samtools_fasta.movie_fasta,
      pb_conda_image = pb_conda_image
  }

  call gfa2fa as gfa2fa_a_ctg {
    input:
      gfa = hifiasm_assemble.a_ctg,
      pb_conda_image = pb_conda_image
  }

  call gfa2fa as gfa2fa_p_ctg {
    input:
      gfa = hifiasm_assemble.p_ctg,
      pb_conda_image = pb_conda_image
  }

  call gfa2fa as gfa2fa_p_utg {
    input:
      gfa = hifiasm_assemble.p_utg,
      pb_conda_image = pb_conda_image
  }

  call gfa2fa as gfa2fa_r_utg {
    input:
      gfa = hifiasm_assemble.r_utg,
      pb_conda_image = pb_conda_image
  }

  call bgzip_fasta as bgzip_fasta_a_ctg {
    input:
      fasta = gfa2fa_a_ctg.fasta,
      pb_conda_image = pb_conda_image
  }

  call bgzip_fasta as bgzip_fasta_p_ctg {
    input:
      fasta = gfa2fa_p_ctg.fasta,
      pb_conda_image = pb_conda_image
  }

  call bgzip_fasta as bgzip_fasta_p_utg {
    input:
      fasta = gfa2fa_p_utg.fasta,
      pb_conda_image = pb_conda_image
  }

  call bgzip_fasta as bgzip_fasta_r_utg {
    input:
      fasta = gfa2fa_r_utg.fasta,
      pb_conda_image = pb_conda_image
  }

  call asm_stats as asm_stats_a_ctg  {
    input:
      fasta_gz = bgzip_fasta_a_ctg.fasta_gz,
      index = target.indexfile,
      pb_conda_image = pb_conda_image
  }

  call asm_stats as asm_stats_p_ctg  {
    input:
      fasta_gz = bgzip_fasta_p_ctg.fasta_gz,
      index = target.indexfile,
      pb_conda_image = pb_conda_image
  }

  call asm_stats as asm_stats_p_utg  {
    input:
      fasta_gz = bgzip_fasta_p_utg.fasta_gz,
      index = target.indexfile,
      pb_conda_image = pb_conda_image
  }

  call asm_stats as asm_stats_r_utg  {
    input:
      fasta_gz = bgzip_fasta_r_utg.fasta_gz,
      index = target.indexfile,
      pb_conda_image = pb_conda_image
  }

  call align_hifiasm {
    input:
      sample_name = sample_name,
      target = target,
      reference_name = target.name,
      query = [
        bgzip_fasta_a_ctg.fasta_gz,
        bgzip_fasta_p_ctg.fasta_gz
      ],
      pb_conda_image = pb_conda_image
  }

  output {
  }
}
