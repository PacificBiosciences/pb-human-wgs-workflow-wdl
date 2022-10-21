version 1.0

#import "../common/structs.wdl"
#import "../sample/tasks/hifiasm_trio.wdl" as hifiasm_trio_assemble



import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/sample.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/yak.wdl" as yak
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/hifiasm_trio.wdl" as hifiasm_trio_assemble

workflow sample_trio {
  input {
    Array[String]             affected_person_sample_names
    Array[Array[IndexedData]] affected_person_sample
    Array[Array[IndexedData]] affected_person_sample_ubam
    Array[Array[String?]]      affected_person_parents_names
    Array[String]             unaffected_person_sample_names
    Array[Array[IndexedData]] unaffected_person_sample
    Array[Array[IndexedData]] unaffected_person_sample_ubam
    Array[Array[String?]]      unaffected_person_parents_names
    String pb_conda_image
    IndexedData reference
    Boolean trioeval
    Boolean triobin
    CohortInfo cohort_info

  }


  Array[Array[String]] affected_person_parents_names_n = select_all(select_first([affected_person_parents_names, [["None"]]]))
  Array[Array[String]] unaffected_person_parents_names_n = select_all(select_first([unaffected_person_parents_names, [["None"]]]))

  call yak.yak_parents {
    input:
      affected_person_parents_names = affected_person_parents_names_n,
      unaffected_person_parents_names = unaffected_person_parents_names_n,
      pb_conda_image = pb_conda_image
  }

  scatter (pa in range(length(affected_person_sample))) {

    scatter (parent_af in range(length(yak_parents.yak_parents))) {

      if (affected_person_sample_names[pa] == yak_parents.yak_parents[parent_af]) {
        call yak.yak as yak_af {
          input:
            sample_name = affected_person_sample_names[pa],
            sample = affected_person_sample_ubam[pa] ,
            pb_conda_image = pb_conda_image
        }
      }
    }
  }


  scatter (pu in range(length(unaffected_person_sample))) {

    scatter (parent_uf in range(length(yak_parents.yak_parents))) {

      if (unaffected_person_sample_names[pu] == yak_parents.yak_parents[parent_uf]) {
        call yak.yak as yak_uf {
          input:
            sample_name = unaffected_person_sample_names[pu],
            sample = unaffected_person_sample_ubam[pu] ,
            pb_conda_image = pb_conda_image
        }
      }
    }
  }

  Array[Pair[String, File]] yak_af_output = select_first([yak_af.yak_output,[("None","None")]])
  Array[Pair[String, File]] yak_uf_output = select_first([yak_uf.yak_output,[("None","None")]])


  scatter (person_num in range(length(affected_person_sample))) {

    Array[String] affected = select_first([affected_person_parents_names[person_num],['None']])

    Int num_parents_affected = length(affected)
    Boolean trio_assembly_affected = if num_parents_affected == 2 then true else false

    if (trio_assembly_affected) {

      String parent1_af = affected[0]
      String parent2_af = affected[1]


      scatter (af_person_num in range(length(yak_af_output))) {
        Pair[String, File] yak1 = yak_af_output[af_person_num]
        if (yak1.left == parent1_af) {
          Pair[String, File] p1_af  = yak1
        }
        if (yak1.left == parent2_af) {
          Pair[String, File] p2_af = yak1
        }
      }

      scatter (unaf_person_num in range(length(yak_uf_output))) {
        Pair[String, File] yak2 = yak_uf_output[unaf_person_num]
        if (yak2.left == parent1_af) {
          Pair[String, File] p1_uf  = yak2
        }
        if (yak2.left == parent2_af) {
          Pair[String, File] p2_uf = yak2
        }
      }      

      Pair[String, File] parent1_sample_af = select_first(select_first([p1_af, p1_uf]))
      Pair[String, File] parent2_sample_af = select_first(select_first([p2_af, p2_uf]))

      call hifiasm_trio_assemble.hifiasm_trio as hifiasm_trio_assemble_affected {
        input:
          sample_name = affected_person_sample_names[person_num],
          sample = affected_person_sample_ubam[person_num],
          yak_parent_1 = parent1_sample_af,
          yak_parent_2 = parent2_sample_af,
          target = reference,
          reference_name = reference.name,
          pb_conda_image = pb_conda_image,
          trioeval = trioeval,
          triobin = triobin
      }
    }
  }

  scatter (person_num_1 in range(length(unaffected_person_sample))) {

    Array[String] unaffected = select_first([unaffected_person_parents_names[person_num_1],['None']])

    Int num_parents_unaffected = length(unaffected)
    Boolean trio_assembly_unaffected = if num_parents_unaffected == 2 then true else false

    if (trio_assembly_unaffected) {

      String parent1_uf = unaffected[0]
      String parent2_uf = unaffected[1]

      scatter (af_person_num_1 in range(length(yak_af_output))) {
        Pair[String, File] yak3 = yak_af_output[af_person_num_1]
          if (yak3.left == parent1_uf) {
            Pair[String, File] p1_u_af  = yak3
          }
          if (yak3.left == parent2_uf) {
            Pair[String, File] p2_u_af = yak3
          }
      }

      scatter (unaf_person_num_1 in range(length(yak_uf_output))) {
        Pair[String, File] yak4 = yak_uf_output[unaf_person_num_1]
        if (yak4.left == parent1_uf) {
          Pair[String, File] p1_u_uf = yak4
        }
        if (yak4.left  == parent2_uf) {
          Pair[String, File] p2_u_uf =yak4
        }
      }

      Pair[String, File] parent1_sample_uf = select_first(select_first([p1_u_af, p1_u_uf]))
      Pair[String, File] parent2_sample_uf = select_first(select_first([p2_u_af, p2_u_uf]))


      call hifiasm_trio_assemble.hifiasm_trio as hifiasm_trio_assemble_unaffected {
        input:
          sample_name = unaffected_person_sample_names[person_num_1],
          sample = unaffected_person_sample_ubam[person_num_1],
          yak_parent_1 = parent1_sample_uf,
          yak_parent_2 = parent2_sample_uf,
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
