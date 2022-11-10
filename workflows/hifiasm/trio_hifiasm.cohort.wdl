version 1.0

import "../common/structs.wdl"
import "./tasks/yak.wdl" as yak
import "./tasks/hifiasm_trio.wdl" as hifiasm_trio_assemble

#import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
#import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/hifiasm/tasks/yak.wdl" as yak
#import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/hifiasm/tasks/hifiasm_trio.wdl" as hifiasm_trio_assemble

workflow trio_hifiasm_cohort {
  input {
    Array[Pair[String,Array[File]]] fasta_info
    Array[Array[String]] person_parents_names
    Array[String]  parents_list
    String pb_conda_image
    IndexedData reference
    Boolean trioeval
    Boolean triobin    
  }

  #consider all siblings having the same parents as often seen, can be generalized in the future
  scatter (sample in fasta_info){
    Array[File] parents_fasta_1 = if (sample.left == parents_list[0]) then sample.right else []
    Array[File] parents_fasta_2 =  if (sample.left == parents_list[1]) then sample.right else []
  }
  
  call yak.yak as person_yak1 {
        input:
          sample_name = parents_list[0],
          movie_fasta = flatten(parents_fasta_1),
          pb_conda_image = pb_conda_image
  }

  call yak.yak as person_yak2 {
        input:
          sample_name = parents_list[1],
          movie_fasta = flatten(parents_fasta_2),
          pb_conda_image = pb_conda_image
  }

  scatter (person_num in range(length(fasta_info))) {
    Int num_parents = length(person_parents_names[person_num])
    Boolean trio_hifiasm = if num_parents == 2 then true else false
    if(trio_hifiasm){ #in case parents not provided for a sibling, we simply skip it
      call hifiasm_trio_assemble.hifiasm_trio as hifiasm_trio_sample {
        input:
          sample_name = fasta_info[person_num].left,
          movie_fasta = fasta_info[person_num].right,
          parent_names = parents_list,
          yak_parent1 = person_yak1.yak_output,
          yak_parent2 = person_yak2.yak_output,
          target = reference,
          reference_name = reference.name,
          pb_conda_image = pb_conda_image,
          trioeval = trioeval,
          triobin = triobin
      }
    }
  }

  output {
  }
}
