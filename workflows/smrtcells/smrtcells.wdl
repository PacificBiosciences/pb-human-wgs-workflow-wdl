version 1.0

import "./tasks/pbmm2.wdl" as pbmm2
import "./tasks/mosdepth.wdl" as mosdepth
import "./tasks/stats.wdl" as stats
import "./tasks/coverage_qc.wdl" as coverage_qc
import "./tasks/jellyfish.wdl" as jellyfish
import "./structs/BamPair.wdl"


workflow smrtcells {
  input {
    String md5sum_name

    IndexedData reference
    String reference_name
    String sample_name
    SmrtcellInfo smrtcell_info
    Int kmer_length

    String pb_conda_image
  }

  call pbmm2.align_ubam_or_fastq {
    input:
      reference = reference,
      reference_name = reference_name,

      sample_name = sample_name,
      smrtcell_info = smrtcell_info,
      pb_conda_image = pb_conda_image
  }

  call mosdepth.mosdepth {
    input:
      bam_pair = align_ubam_or_fastq.bam_pair,
      smrtcell_name = smrtcell_info.name,
      reference_name = reference_name,

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
      reference_name = reference_name,
      mosdepth_summary = mosdepth.summary,
      pb_conda_image = pb_conda_image
  }

  call jellyfish.jellyfish {
    input:
      smrtcell_info = smrtcell_info,
      kmer_length = kmer_length,
      pb_conda_image = pb_conda_image,
  }

  output {
    IndexedData bam_pair  = align_ubam_or_fastq.bam_pair
    File count_jf     = jellyfish.count_jf
  }

}
