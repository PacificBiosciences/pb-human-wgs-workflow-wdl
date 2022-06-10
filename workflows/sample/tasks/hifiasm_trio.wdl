version 1.0

#import "../../common/structs.wdl"

import "https://raw.githubusercontent.com/ducatiMonster916/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/ducatiMonster916/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/hifiasm.wdl" as hifiasm


task hifiasm_trio_assemble {
  input {
    Int threads = 48
    String sample_name
    String prefix = "~{sample_name}.asm"
    String log_name = "hifiasm.log"

    Array[File] movie_fasta
    File parent1_yak
    File parent2_yak
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

    (hifiasm -o ~{prefix} -t ~{threads} -1 {parent1_yak} -2 {parent2_yak} ~{sep=" " movie_fasta} \
    && (echo -e "hap1\t{params.parent1}\nhap2\t{params.parent2}" > ~{prefix}.key.txt) > ~{log_name} 2>&1
  >>>
  output {
    File hap1_p_ctg        = "~{prefix}.bp.hap1.p_ctg.gfa"
    File hap1_p_ctg_lowQ   = "~{prefix}.bp.hap1.p_ctg.lowQ.bed"
    File hap1_p_noseq      = "~{prefix}.bp.hap1.p_ctg.noseq.gfa"
    File hap2_p_ctg        = "~{prefix}.bp.hap2.p_ctg.gfa"
    File hap2_p_ctg_lowQ   = "~{prefix}.bp.hap2.p_ctg.lowQ.bed"
    File hap2_p_noseq      = "~{prefix}.bp.hap2.p_ctg.noseq.gfa"
    File p_ctg             = "~{prefix}.bp.p_ctg.gfa"
    File p_utg             = "~{prefix}.bp.p_utg.gfa"
    File r_utg             = "~{prefix}.bp.r_utg.gfa"
    File ec_bin            = "~{prefix}.ec.bin"
    File ovlp_rev_bin      = "~{prefix}.ovlp.reverse.bin"
    File ovlp_src_bin      = "~{prefix}.ovlp.source.bin"
    File key               = "~{prefix}.key.txt"

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

task yak_trioeval {
  input {
    Int threads = 16
    File fasta_gz
    String yak_trioeval_txt_name = "~{basename(fasta_gz)}.trioeval.txt"
    String log_name = "yak.fasta.trioeval.log"
    File parent1_yak
    File parent2_yak
  }

  Float multiplier = 2
  Int disk_size = ceil(multiplier * size(movie_fasta, "GB")) + 20
#  Int disk_size = 200
  Int memory = threads * 3              #forces at least 3GB RAM/core, even if user overwrites threads

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate yak
    echo "$(conda info)"

    (yak trioeval  -t {threads} -1 {parent1_yak} -2 {parent2_yak} > {yak_trioeval_txt_name} ) > {log_name} 2>&1
  >>>
  output {
    File yak_trioeval_txt_name  = "~{yak_trioeval_txt_name}"

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

workflow hifiasm_trio {
  input {
    String sample_name
    Array[IndexedData] sample
    Array[String?] parent_names
    IndexedData target
    String? reference_name
    String pb_conda_image
    Array[Pair[String,File]] yak_count
  }

  Int num_parents = length(parent_names)
  Boolean trio = if num_parents == 2 then true else false

  File parent1_yak = yak_count[0]."~{parent_names[0]}"
  File parent2_yak = yak_count[1]."~{parent_names[1]}"

  scatter (movie in sample) {
    call hifiasm.samtools_fasta as samtools_fasta {
      input:
        movie = movie,
        pb_conda_image = pb_conda_image
    }
  }

  call hifiasm_trio_assemble {
    input:
      sample_name = sample_name,
      movie_fasta = samtools_fasta.movie_fasta,
      parent1_yak = parent1_yak,
      parent2_yak = parent2_yak,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.gfa2fa as gfa2fa_hap1_p_ctg {
    input:
      gfa = hifiasm_assemble.hap1_p_ctg,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.gfa2fa as gfa2fa_hap2_p_ctg {
    input:
      gfa = hifiasm_assemble.hap2_p_ctg,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.gfa2fa as gfa2fa_p_ctg {
    input:
      gfa = hifiasm_assemble.p_ctg,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.gfa2fa as gfa2fa_p_utg {
    input:
      gfa = hifiasm_assemble.p_utg,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.gfa2fa as gfa2fa_r_utg {
    input:
      gfa = hifiasm_assemble.r_utg,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.bgzip_fasta as bgzip_fasta_hap1_p_ctg {
    input:
      fasta = gfa2fa_hap1_p_ctg.fasta,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.bgzip_fasta as bgzip_fasta_hap2_p_ctg {
    input:
      fasta = gfa2fa_hap2_p_ctg.fasta,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.bgzip_fasta as bgzip_fasta_p_ctg {
    input:
      fasta = gfa2fa_p_ctg.fasta,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.bgzip_fasta as bgzip_fasta_p_utg {
    input:
      fasta = gfa2fa_p_utg.fasta,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.bgzip_fasta as bgzip_fasta_r_utg {
    input:
      fasta = gfa2fa_r_utg.fasta,
      pb_conda_image = pb_conda_image
  }
  call yak_trioeval as yak_trioeval_hap1_p_ctg  {
    input:
      fasta_gz = bgzip_fasta_hap1_p_ctg.fasta_gz,
      index = target.indexfile,
      parent1_yak = parent1_yak,
      parent2_yak = parent2_yak,
      pb_conda_image = pb_conda_image
  }

  call yak_trioeval as yak_trioeval_hap2_p_ctg  {
    input:
      fasta_gz = bgzip_fasta_hap2_p_ctg.fasta_gz,
      index = target.indexfile,
      parent1_yak = parent1_yak,
      parent2_yak = parent2_yak,
      pb_conda_image = pb_conda_image
  }

  call yak_trioeval as yak_trioeval_p_ctg  {
    input:
      fasta_gz = bgzip_fasta_p_ctg.fasta_gz,
      index = target.indexfile,
      parent1_yak = parent1_yak,
      parent2_yak = parent2_yak,
      pb_conda_image = pb_conda_image
  }

  call yak_trioeval as yak_trioeval_p_utg  {
    input:
      fasta_gz = bgzip_fasta_p_utg.fasta_gz,
      index = target.indexfile,
      parent1_yak = parent1_yak,
      parent2_yak = parent2_yak,
      pb_conda_image = pb_conda_image
  }

  call yak_trioeval as yak_trioeval_r_utg  {
    input:
      fasta_gz = bgzip_fasta_r_utg.fasta_gz,
      index = target.indexfile,
      parent1_yak = parent1_yak,
      parent2_yak = parent2_yak,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.asm_stats as asm_stats_hap1_p_ctg  {
    input:
      fasta_gz = bgzip_fasta_hap1_p_ctg.fasta_gz,
      index = target.indexfile,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.asm_stats as asm_stats_hap2_p_ctg  {
    input:
      fasta_gz = bgzip_fasta_hap2_p_ctg.fasta_gz,
      index = target.indexfile,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.asm_stats as asm_stats_p_ctg  {
    input:
      fasta_gz = bgzip_fasta_p_ctg.fasta_gz,
      index = target.indexfile,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.asm_stats as asm_stats_p_utg  {
    input:
      fasta_gz = bgzip_fasta_p_utg.fasta_gz,
      index = target.indexfile,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.asm_stats as asm_stats_r_utg  {
    input:
      fasta_gz = bgzip_fasta_r_utg.fasta_gz,
      index = target.indexfile,
      pb_conda_image = pb_conda_image
  }

  call hifiasm.align_hifiasm {
    input:
      sample_name = sample_name,
      target = target,
      reference_name = reference_name,
      query = [
        bgzip_fasta_hap1_p_ctg.fasta_gz,
        bgzip_fasta_hap2_p_ctg.fasta_gz
      ],
      pb_conda_image = pb_conda_image
  }

  output {
  }
}
