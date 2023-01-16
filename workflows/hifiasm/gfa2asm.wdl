version 1.0

import "../common/structs.wdl"
import "tasks/gfa2stats.wdl" as gfa2stats

workflow gfa2asm {
  input {
    File hap1_p_ctg_gfa
    File hap2_p_ctg_gfa
    File p_ctg_gfa
    File p_utg_gfa
    File r_utg_gfa

    IndexedData reference
    String pb_conda_image
  }

  Array[String] gfa_strs = ["hap1_p_ctg_gfa", "hap2_p_ctg_gfa", "p_ctg_gfa", "p_utg_gfa", "r_utg_gfa"]
  Map[String, File] gfa_map = {
    "hap1_p_ctg_gfa": "~{hap1_p_ctg_gfa}",
    "hap2_p_ctg_gfa": "~{hap2_p_ctg_gfa}",
    "p_ctg_gfa": "~{p_ctg_gfa}",
    "p_utg_gfa": "~{p_utg_gfa}",
    "r_utg_gfa": "~{r_utg_gfa}"
  }

  scatter (gfa in gfa_strs){ 
    call gfa2stats.gfa2stats as gfa_stats {
      input:
        gfa = gfa_map[gfa],
        index = reference.indexfile,
        pb_conda_image = pb_conda_image
    }
  }

  output {
    File hap1_fasta_gz = gfa_stats.fasta_gz[0] 
    File hap2_fasta_gz = gfa_stats.fasta_gz[1]
  }
}

