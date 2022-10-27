version 1.0

#import "../../common/structs.wdl"
#import "./common.wdl" as common
#import "../../common/separate_data_and_index_files.wdl"

import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/common.wdl" as common
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/common/separate_data_and_index_files.wdl"


task last_align {
    input {
        LastIndexedData last_reference
        File haplotagged_bam
        File haplotagged_bai
        File tg_bed
        File score_matrix
        String sample_name
        Int threads = 24
        String pb_conda_image
    }

    File last_reference_bck     = last_reference.last_reference_bck
    File last_reference_des     = last_reference.last_reference_des
    File last_reference_prj     = last_reference.last_reference_prj
    File last_reference_sds     = last_reference.last_reference_sds
    File last_reference_ssp     = last_reference.last_reference_ssp
    File last_reference_suf     = last_reference.last_reference_suf
    File last_reference_tis     = last_reference.last_reference_tis

    output {
        File tg_maf = "~{sample_name}.maf.gz"
    }

    String extra = "-C2"

    String last_reference_name = basename(last_reference_bck, ".lastdb.bck")
    String score_matrix_name = basename(score_matrix, ".par")

    Int disk_size = ceil(size(last_reference_bck, "GB") + size(haplotagged_bam, "GB") + size(tg_bed, "GB") + size(score_matrix, "GB") *3)

    command <<<
        source ~/.bashrc
        conda activate last
        echo "$(conda info)"

        echo "Outputting ~{sample_name}.maf.gz."

       echo "Aligning ~{tg_bed} regions of ~{haplotagged_bam} to ~{last_reference_name} using lastal with ~{score_matrix_name} score matrix."
       last_reference_suf="~{last_reference_suf}"
       last_reference_base="${last_reference_suf%.suf}"

       samtools view -@3 -bL ~{tg_bed} ~{haplotagged_bam} | samtools fasta \
         | lastal -P20 -p ~{score_matrix} ~{extra} ${last_reference_base} - \
         | last-split | bgzip > ~{sample_name}.maf.gz
    >>>

    runtime {
        docker: "~{pb_conda_image}"
        preemptible: true
        maxRetries: 3
        cpu: "~{threads}"
        disk: "~{disk_size}" + " GB"
    }
}

task call_tandem_genotypes {
    input {
        File maf
        File tg_list_file
        String sample_name
        String pb_conda_image
    }

    Int disk_size = ceil (size(maf, "GB") + size(tg_list_file, "GB") * 1.5)

    output {
        File sample_tg_list = "~{sample_name}.tandem-genotypes.txt"
    }

    command <<<
        source ~/.bashrc
        conda activate tandem-genotypes
        echo "$(conda info)"

        echo "Generating tandem repeats from ~{tg_list_file} regions in ~{maf} to ~{sample_name}."

        tandem-genotypes ~{tg_list_file} ~{maf} > ~{sample_name}.tandem-genotypes.txt
    >>>

    runtime {
        docker: "~{pb_conda_image}"
        preemptible: true
        maxRetries: 3
        cpu: 4
        disk: "~{disk_size}" + " GB"
    }

}

task tandem_genotypes_absolute_count {
    input {
        File sample_tandem_genotypes
        String sample_name
        String pb_conda_image
    }

    output {
        File sample_tandem_genotypes_absolute = "~{sample_name}.tandem-genotypes.absolute.txt"
    }

    Int disk_size = ceil(size(sample_tandem_genotypes, "GB") * 2)

    command <<<

        echo "Adjusting repeat count with reference counts for ~{sample_tandem_genotypes} to ~{sample_name}.tandem-genotypes.absolute.txt."

        awk -v OFS='\t' \
            '$0 ~ /^#/ {{print $0 " modified by adding reference repeat count"}}
            $0 !~ /^#/ {{
                ref_count=int(($3-$2)/length($4));
                num_fwd=split($7, fwd, ",");
                num_rev=split($8, rev, ",");
                new_fwd=result=fwd[1] + ref_count;
                for (i=2; i<=num_fwd; i++)
                    new_fwd = new_fwd "," fwd[i] + ref_count;
                new_rev=rev[1] + ref_count;
                for (i=2; i<=num_rev; i++)
                    new_rev = new_rev "," rev[i] + ref_count;
                print $1, $2, $3, $4, $5, $6, new_fwd, new_rev;
            }}' ~{sample_tandem_genotypes} > ~{sample_name}.tandem-genotypes.absolute.txt
    >>>

    runtime {
        docker: "~{pb_conda_image}"
        preemptible: true
        maxRetries: 3
        cpu: 4
        disk: "~{disk_size}" + " GB"
    }
}

task tandem_genotypes_plot {
    input {
        File sample_tandem_genotypes
        String sample_name
        String pb_conda_image
    }

    output {
        File sample_tg_plot = "~{sample_name}.tandem-genotypes.pdf"
    }

    Int top_N_plots = 100
    Int disk_size = ceil(size(sample_tandem_genotypes, "GB") * 3)

    command <<<
        source ~/.bashrc
        conda activate tandem-genotypes
        echo "$(conda info)"

        echo "Plotting tandem repeat count for ~{sample_tandem_genotypes} to ~{sample_name}.tandem-genotypes.pdf."

        tandem-genotypes-plot -v -n ~{top_N_plots} ~{sample_tandem_genotypes} ./~{sample_name}.tandem-genotypes.pdf

        # Find files, not clear why its curerntly not discoverable in the docker image but this seems to make it work
        find / -type f
    >>>

    runtime {
        docker: "~{pb_conda_image}"
        preemptible: true
        maxRetries: 3
        cpu: 4
        disk: "~{disk_size}" + " GB"
    }
}

task tandem_repeat_coverage_dropouts {
    input {
        File haplotagged_bam
        File haplotagged_bai
        File tg_bed
        String sample_name
        String pb_conda_image
        String tandem_repeat_coverage_dropouts_log = "~{sample_name}.tandem-genotypes.dropouts.log"
    }

    output {
        File log = "~{tandem_repeat_coverage_dropouts_log}"
        File tandem_genotypes_dropouts = "~{sample_name}.tandem-genotypes.dropouts.txt"
    }

    Int disk_size = ceil(size(haplotagged_bam, "GB") * 2)

    command <<<
        source ~/.bashrc
        conda activate tandem-genotypes
        echo "$(conda info)"

        echo "Identify coverage dropouts in ~{tg_bed} regions in ~{haplotagged_bam}."
        (python3 /opt/pb/scripts/check_tandem_repeat_coverage.py ~{tg_bed} ~{haplotagged_bam} > ~{sample_name}.tandem-genotypes.dropouts.txt) > ~{tandem_repeat_coverage_dropouts_log} 2>&1
    >>>

    runtime {
        docker: "~{pb_conda_image}"
        preemptible: true
        maxRetries: 3
        cpu: 4
        disk: "~{disk_size}" + " GB"
    }

}

workflow tandem_genotypes {

  input {
    File tg_list
    File tg_bed
    LastIndexedData last_reference
    String sample_name
    File score_matrix
    File haplotagged_bam
    File haplotagged_bai
    String pb_conda_image
  }

  call last_align {
    input:
        sample_name = sample_name,
        last_reference = last_reference,
        haplotagged_bam = haplotagged_bam,
        haplotagged_bai = haplotagged_bai,
        tg_bed = tg_bed,
        score_matrix = score_matrix,
        threads = 24,
        pb_conda_image = pb_conda_image
  }

    call call_tandem_genotypes {
        input:
            maf = last_align.tg_maf,
            tg_list_file = tg_list,
            sample_name = sample_name,
            pb_conda_image = pb_conda_image
    }

    call tandem_genotypes_absolute_count {
        input:
            sample_tandem_genotypes = call_tandem_genotypes.sample_tg_list,
            sample_name = sample_name,
            pb_conda_image = pb_conda_image
    }

    call tandem_genotypes_plot {
        input:
            sample_tandem_genotypes = tandem_genotypes_absolute_count.sample_tandem_genotypes_absolute,
            sample_name = sample_name,
            pb_conda_image = pb_conda_image
    }

    call tandem_repeat_coverage_dropouts {
        input:
            haplotagged_bam = haplotagged_bam,
            haplotagged_bai = haplotagged_bai,
            tg_bed = tg_bed,
            sample_name = sample_name,
            pb_conda_image = pb_conda_image
    }

    output {
        File sample_tandem_genotypes = call_tandem_genotypes.sample_tg_list
        File sample_tandem_genotypes_absolute = tandem_genotypes_absolute_count.sample_tandem_genotypes_absolute
        File sample_tandem_genotypes_plot = tandem_genotypes_plot.sample_tg_plot
        File sample_tandem_genotypes_dropouts = tandem_repeat_coverage_dropouts.tandem_genotypes_dropouts
    }

}
