version 1.0

#import "../common/structs.wdl"
i#mport "../sample/tasks/hifiasm_trio.wdl" as hifiasm_trio_assemble


import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/sample.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/yak.wdl" as yak
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/hifiasm_trio.wdl" as hifiasm_trio_assemble

workflow sample_trio {
  input {
    Array[String]             affected_person_sample_names
    Array[Array[IndexedData]] affected_person_sample
    Array[Array[String]?]      affected_person_parents_names
    Array[String]             unaffected_person_sample_names
    Array[Array[IndexedData]] unaffected_person_sample
    Array[Array[String]?]      unaffected_person_parents_names
    String pb_conda_image
    IndexedData reference
    Boolean trioeval
    Boolean triobin
    CohortInfo cohort_info

  }

  scatter (person_num in range(length(affected_person_sample))) {

    Array[String] affected = select_first([affected_person_parents_names[person_num],['None']])

    Int num_parents_affected = length(affected)
    Boolean trio_assembly_affected = if num_parents_affected == 2 then true else false

    if (trio_assembly_affected) {

      String parent1_af = affected[0]
      String parent2_af = affected[1]


      scatter (af_person_num in range(length(affected_person_sample))) {
          if (affected_person_sample_names[af_person_num] == parent1_af) {
            Array[IndexedData] p1_af = affected_person_sample[af_person_num]
          }
          if (affected_person_sample_names[af_person_num] == parent2_af) {
            Array[IndexedData] p2_af = affected_person_sample[af_person_num]
          }
      }

      scatter (unaf_person_num in range(length(unaffected_person_sample))) {
        if (unaffected_person_sample_names[unaf_person_num] == parent1_af) {
          Array[IndexedData] p1_uf = unaffected_person_sample[unaf_person_num]
        }
        if (unaffected_person_sample_names[unaf_person_num] == parent2_af) {
          Array[IndexedData] p2_uf = unaffected_person_sample[unaf_person_num]
        }
      }

      Array[IndexedData] parent1_sample_af = select_first(select_first([p1_af, p1_uf]))
      Array[IndexedData] parent2_sample_af = select_first(select_first([p2_af, p2_uf]))

      call yak.yak as yak_af_parent_1 {
        input:
          sample_name = parent1_af,
          sample = parent1_sample_af,
          pb_conda_image = pb_conda_image
      }

      call yak.yak as yak_af_parent_2 {
        input:
          sample_name = parent2_af,
          sample = parent2_sample_af,
          pb_conda_image = pb_conda_image
      }


      call hifiasm_trio_assemble.hifiasm_trio as hifiasm_trio_assemble_affected {
        input:
          sample_name = affected_person_sample_names[person_num],
          sample = affected_person_sample[person_num],
          yak_parent_1 = yak_af_parent_1.yak_output,
          yak_parent_2 = yak_af_parent_2.yak_output,
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


      scatter (af_person_num_1 in range(length(affected_person_sample))) {
          if (affected_person_sample_names[af_person_num_1] == parent1_uf) {
            Array[IndexedData] p1_u_af = affected_person_sample[af_person_num_1]
          }
          if (affected_person_sample_names[af_person_num_1] == parent2_uf) {
            Array[IndexedData] p2_u_af = affected_person_sample[af_person_num_1]
          }
      }

      scatter (unaf_person_num_1 in range(length(unaffected_person_sample))) {
        if (unaffected_person_sample_names[unaf_person_num_1] == parent1_uf) {
          Array[IndexedData] p1_u_uf = unaffected_person_sample[unaf_person_num_1]
        }
        if (unaffected_person_sample_names[unaf_person_num_1] == parent2_uf) {
          Array[IndexedData] p2_u_uf = unaffected_person_sample[unaf_person_num_1]
        }
      }
      Array[IndexedData] parent1_sample_uf = select_first(select_first([p1_u_af, p1_u_uf]))
      Array[IndexedData] parent2_sample_uf = select_first(select_first([p2_u_af, p2_u_uf]))

      call yak.yak as yak_uf_parent_1 {
        input:
          sample_name = parent1_uf,
          sample = parent1_sample_uf,
          pb_conda_image = pb_conda_image
      }

      call yak.yak as yak_uf_parent_2 {
        input:
          sample_name = parent2_uf,
          sample = parent2_sample_uf,
          pb_conda_image = pb_conda_image
      }


      call hifiasm_trio_assemble.hifiasm_trio as hifiasm_trio_assemble_unaffected {
        input:
          sample_name = unaffected_person_sample_names[person_num_1],
          sample = unaffected_person_sample[person_num_1],
          yak_parent_1 = yak_uf_parent_1.yak_output,
          yak_parent_2 = yak_uf_parent_2.yak_output,
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
