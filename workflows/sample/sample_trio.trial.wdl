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



  scatter (person_num in range(length(unaffected_person_sample))) {
    call yak.yak as yak_unaffected_person {
      input:
        sample_name = unaffected_person_sample_names[person_num],
        sample = unaffected_person_sample[person_num],
        pb_conda_image = pb_conda_image

    }
  }

  scatter (person_num in range(length(affected_person_sample))) {
    call yak.yak as yak_affected_person {
      input:
        sample_name = affected_person_sample_names[person_num],
        sample = affected_person_sample[person_num],
        pb_conda_image = pb_conda_image

    }
  }

  Array[Pair[String, File]] yak_person = flatten(select_all([yak_unaffected_person.yak_output, yak_affected_person.yak_output]))

  scatter (person_num in range(length(affected_person_sample))) {

    Array[String] affected = select_first([affected_person_parents_names[person_num],['None']])

    Int num_parents_affected = length(affected)
    Boolean trio_assembly_affected = if num_parents_affected == 2 then true else false

    if (trio_assembly_affected) {
      call hifiasm_trio_assemble.hifiasm_trio as hifiasm_trio_assemble_affected {
        input:
          sample_name = affected_person_sample_names[person_num],
          sample = affected_person_sample[person_num],
          parent_names = affected_person_parents_names[person_num],
          yak_count = yak_person,
          target = reference,
          reference_name = reference.name,
          pb_conda_image = pb_conda_image,
          trioeval = trioeval,
          triobin = triobin
      }
    }
  }

  scatter (person_num in range(length(unaffected_person_sample))) {

    Array[String] unaffected = select_first([unaffected_person_sample[person_num],['None']])


    Int num_parents_unaffected = length(unaffected)
    Boolean trio_assembly_unaffected = if num_parents_unaffected == 2 then true else false

    if (trio_assembly_unaffected) {
      call hifiasm_trio_assemble.hifiasm_trio as hifiasm_trio_assemble_unaffected {
        input:
          sample_name = unaffected_person_sample_names[person_num],
          sample = unaffected_person_sample[person_num],
          parent_names = unaffected_person_parents_names[person_num],
          yak_count = yak_person,
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
