version 1.0

# The new workflow, fasta_conversion.wdl, is called here

import "tasks/pbmm2.wdl" as pbmm2
import "tasks/mosdepth.wdl" as mosdepth
import "tasks/stats.wdl" as stats
import "tasks/coverage_qc.wdl" as coverage_qc
import "tasks/jellyfish.wdl" as jellyfish
import "../common/structs.wdl"
import "tasks/fasta_conversion.wdl" as fasta_conversion


workflow smrtcells {
  input {
    IndexedData reference
    String sample_name
    SmrtcellInfo smrtcell_info
    Int kmer_length

    String pb_conda_image
    Boolean run_jellyfish                        # optional- default: null. ONLY if run_jellyfish=true, run jellyfish. Specify in the default_settings.json file
  }

  call pbmm2.align_ubam_or_fastq {
    input:
      reference = reference,

      sample_name = sample_name,
      smrtcell_info = smrtcell_info,
      pb_conda_image = pb_conda_image
  }

  call mosdepth.mosdepth {
    input:
      bam = align_ubam_or_fastq.bam,
      smrtcell_name = smrtcell_info.name,
      reference_name = reference.name,

      pb_conda_image = pb_conda_image
  }

  call stats.stats {
    input:
      smrtcell_info = smrtcell_info,
      pb_conda_image = pb_conda_image
  }

  call coverage_qc.coverage_qc {
    input:
      smrtcell_info = smrtcell_info,
      reference_name = reference.name,
      mosdepth_summary = mosdepth.summary,
      pb_conda_image = pb_conda_image
  }

  if(run_jellyfish) {
    call fasta_conversion.fasta_conversion  {
      input:
        movie = smrtcell_info,
        pb_conda_image = pb_conda_image
    }

    call jellyfish.jellyfish {
      input:
        smrtcell_info = smrtcell_info,
        movie_fasta = fasta_conversion.movie_fasta,
        kmer_length = kmer_length,
        pb_conda_image = pb_conda_image,
    }
  }

  output {
    IndexedData bam = align_ubam_or_fastq.bam
    File? count_jf   = jellyfish.count_jf
    File? movie_modimers = jellyfish.modimers_tsv
  }
}
