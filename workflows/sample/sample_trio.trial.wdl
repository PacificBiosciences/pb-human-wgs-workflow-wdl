version 1.1

#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/ducatiMonster916/pb-human-wgs-workflow-wdl/main/workflows/sample/sample.wdl"
import "https://raw.githubusercontent.com/ducatiMonster916/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/ducatiMonster916/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/yak.wdl" as yak
import "https://raw.githubusercontent.com/ducatiMonster916/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/hifiasm_trio_assemble.wdl" as hifiasm_trio_assemble

workflow sample_trio {
  input {
    Array[String]             affected_person_sample_names
    Array[Array[IndexedData]] affected_person_sample
    Array[Array[String]]      affected_person_parents_names
    Array[String]             unaffected_person_sample_names
    Array[Array[IndexedData]] unaffected_person_sample

    IndexedData reference
  }

  scatter (person_num in range(length(unaffected_person_sample))) {
    call yak.yak as yak_unaffected_person {
      input:
        sample_name = unaffected_person_sample_names[person_num],
        movie_fasta = unaffected_person_sample[person_num],
    }
  }

  scatter (person_num in range(length(affected_person_sample))) {
    call hifiasm_trio_assemble.hifiasm_trio_assemble as hifiasm_trio_assemble {
      input:
        sample_name = affected_person_sample_names[person_num],
        movie_fasta = affected_person_sample[person_num],
        parent_names = affected_person_parents_names[person_num],
        yak_count = yak_unaffected_person.yak_output,
        target = reference,
        reference_name = reference.name
    }
  }

  output {
    Array[IndexedData] affected_person_gvcf                        = if defined(sample_affected_person.gvcf)                        then sample_affected_person.gvcf else []
    Array[Array[Array[File]]] affected_person_svsig_gv             = if defined(sample_affected_person.svsig_gv)                    then sample_affected_person.svsig_gv else []
    Array[IndexedData] affected_person_deepvariant_phased_vcf_gz   = if defined(sample_affected_person.deepvariant_phased_vcf_gz)   then sample_affected_person.deepvariant_phased_vcf_gz else 0
    Array[File?] affected_person_jellyfish_output_files            = if defined(sample_affected_person.jellyfish_output)            then sample_affected_person.jellyfish_output else []
    Array[File?] affected_person_tandem_genotypes                  = if defined(sample_affected_person.tandem_genotypes)            then sample_affected_person.tandem_genotypes else []
    Array[File?] affected_person_tandem_genotypes_absolute         = if defined(sample_affected_person.tandem_genotypes_absolute)   then sample_affected_person.tandem_genotypes_absolute else []
    Array[File?] affected_person_tandem_genotypes_plot             = if defined(sample_affected_person.tandem_genotypes_plot)       then sample_affected_person.tandem_genotypes_plot else []
    Array[File?] affected_person_tandem_genotypes_dropouts         = if defined(sample_affected_person.sample_tandem_genotypes_dropouts) then sample_affected_person.tandem_genotypes_dropouts else []

    Array[IndexedData] unaffected_person_gvcf                      = if defined(sample_unaffected_person.gvcf)                      then sample_unaffected_person.gvcf else []
    Array[Array[Array[File]]] unaffected_person_svsig_gv           = if defined(sample_unaffected_person.svsig_gv)                  then sample_unaffected_person.svsig_gv else []
    Array[IndexedData] unaffected_person_deepvariant_phased_vcf_gz = if defined(sample_unaffected_person.deepvariant_phased_vcf_gz) then sample_unaffected_person.deepvariant_phased_vcf_gz else 0
    Array[File?] unaffected_person_jellyfish_output_files          = if defined(sample_unaffected_person.jellyfish_output)          then sample_unaffected_person.jellyfish_output else []
    Array[File?] unaffected_person_tandem_genotypes                = if defined(sample_unaffected_person.tandem_genotypes)          then sample_unaffected_person.tandem_genotypes else []
    Array[File?] unaffected_person_tandem_genotypes_absolute       = if defined(sample_unaffected_person.tandem_genotypes_absolute) then sample_unaffected_person.tandem_genotypes_absolute else []
    Array[File?] unaffected_person_tandem_genotypes_plot           = if defined(sample_unaffected_person.tandem_genotypes_plot)     then sample_unaffected_person.tandem_genotypes_plot else []
    Array[File?] unaffected_person_tandem_genotypes_dropouts       = if defined(sample_unaffected_person.sample_tandem_genotypes_dropouts) then sample_unaffected_person.tandem_genotypes_dropouts else []
  }
}
