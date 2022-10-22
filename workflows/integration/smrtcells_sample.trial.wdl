version 1.0

#import "../smrtcells/smrtcells.trial.wdl"
#import "../sample/sample.trial.wdl"
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/vsmalladi/pb-human-wgs-workflow-wdl/main/workflows/smrtcells/smrtcells.trial.wdl"
import "https://raw.githubusercontent.com/vsmalladi/pb-human-wgs-workflow-wdl/main/workflows/sample/sample.trial.wdl"
import "https://raw.githubusercontent.com/vsmalladi/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

workflow smrtcells_sample_trial {
  input {
    IndexedData reference
    File regions_file
    CohortInfo cohort_info
    Int kmer_length

    File tr_bed
    File chr_lengths

    String pb_conda_image
    String deepvariant_image

    
    File? tg_list
    File? tg_list_url
    File score_matrix
  }

  call smrtcells.trial.smrtcells_trial {
    input:
      reference = reference,
      cohort_info = cohort_info,
      kmer_length = kmer_length,

      pb_conda_image = pb_conda_image
  }

  call sample.trial.sample_trial {
    input:
    affected_person_sample_names      = smrtcells_trial.affected_person_sample_names,
    affected_person_sample            = smrtcells_trial.affected_person_bams,
    affected_person_jellyfish_input   = smrtcells_trial.affected_person_jellyfish_count,
    unaffected_person_sample_names    = smrtcells_trial.unaffected_person_sample_names,
    unaffected_person_sample          = smrtcells_trial.unaffected_person_bams,
    unaffected_person_jellyfish_input = smrtcells_trial.unaffected_person_jellyfish_count,

    regions_file = regions_file,
    reference = reference,

    tr_bed = tr_bed,
    chr_lengths = chr_lengths,

    pb_conda_image = pb_conda_image,
    deepvariant_image = deepvariant_image,

    tg_list = tg_list,
    tg_list_url = tg_list_url,
    score_matrix = score_matrix
  }

  output {
    Array[Array[IndexedData]] affected_person_bams        = smrtcells_trial.affected_person_bams
    Array[Array[File]] affected_person_jellyfish_count    = smrtcells_trial.affected_person_jellyfish_count

    Array[Array[IndexedData]] unaffected_person_bams      = smrtcells_trial.unaffected_person_bams
    Array[Array[File]] unaffected_person_jellyfish_count  = smrtcells_trial.unaffected_person_jellyfish_count

    Array[IndexedData] affected_person_gvcf                        = sample_trial.affected_person_gvcf
    Array[Array[Array[File]]] affected_person_svsig_gv             = sample_trial.affected_person_svsig_gv
    Array[IndexedData] affected_person_deepvariant_phased_vcf_gz   = sample_trial.affected_person_deepvariant_phased_vcf_gz
    Array[IndexedData] affected_person_tandem_genotypes            = sample_trial.affected_person_tandem_genotypes
    Array[IndexedData] affected_person_tandem_genotypes_absolute   = sample_trial.affected_person_tandem_genotypes_absolute
    Array[IndexedData] affected_person_tandem_genotypes_plot       = sample_trial.affected_person_tandem_genotypes_plot 
    Array[IndexedData] affected_person_tandem_genotypes_dropouts   = sample_trial.affected_person_tandem_genotypes_dropouts


    Array[IndexedData] unaffected_person_gvcf                       = sample_trial.unaffected_person_gvcf
    Array[Array[Array[File]]] unaffected_person_svsig_gv            = sample_trial.unaffected_person_svsig_gv
    Array[IndexedData] unaffected_person_deepvariant_phased_vcf_gz  = sample_trial.unaffected_person_deepvariant_phased_vcf_gz
    Array[IndexedData] unaffected_person_tandem_genotypes           = sample_trial.unaffected_person_tandem_genotypes
    Array[IndexedData] unaffected_person_tandem_genotypes_absolute  = sample_trial.unaffected_person_tandem_genotypes_absolute
    Array[IndexedData] unaffected_person_tandem_genotypes_plot      = sample_trial.unaffected_person_tandem_genotypes_plot
    Array[IndexedData] unaffected_person_tandem_genotypes_dropouts  = sample_trial.unaffected_person_tandem_genotypes_dropouts

  }
}
