version 1.1

#import "../../common/structs.wdl"
#import "./common.wdl" as common
#import "../../common/separate_data_and_index_files.wdl"

import "https://raw.githubusercontent.com/ducatiMonster916/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/ducatiMonster916/pb-human-wgs-workflow-wdl/main/workflows/sample/tasks/common.wdl" as common
import "https://raw.githubusercontent.com/ducatiMonster916/pb-human-wgs-workflow-wdl/main/workflows/common/separate_data_and_index_files.wdl"


task download_tg_list {
    input {
        String tg_list_url
    }

    command <<<
        wget -O tg_list.txt $tg_list_url
        echo "Downloading a list of loci with disease-associated repeats to use from ~{tg_list_url}. For bulk or secure workflows- please download the list of loci and save it in an accessible blob container in your Azure subscription. If your workflow fails at this step, you do not have permission to download external files to your Azure subscription. Please contact your Azure administrator to resolve this issue, or save the file to your Azure blob storage account and provide Cromwell access to it."
    >>>

    output {
        File tg_list_file = "tg_list.txt"
    }

    runtime {
        docker: "ubuntu:latest"
        cpu: "1"
    }
}

task generate_tg_bed {
    
    input {
        File tg_list
        IndexedData reference
        Int threads = 4
    }
    
    output {
        File tg_bed = "tg_bed.bed"
    }

    Int disk_size = ceil(size(tg_list, "GB") * 1.5)

    command <<<

        source ~/.bashrc
        conda activate bedtools
        echo "$(conda info)"
        
        echo "Generating a bed file of loci with disease-associated repeats from ~{tg_list} to generate final bed file for analyses."
        
        Int slop = 1000
    
        echo "Adding ~{slop}bp slop to ~{tg_list} to generate final tg_list.bed."
    
        (grep -v '^#' {input.tg_list} | sort -k1,1V -k2,2g \
        | bedtools slop -b {params.slop} -g {input.fai} -i - \
        > {output}) > {log} 2>&1
    >>>
    
    runtime {
        docker: "~{pb_conda_image}"
        preemptible: true
        maxRetries: 3
        cpu: "~{threads}"
        disk: disk_size + " GB"
    }
}

task generate_last_index {
    input { 
        File reference_fasta
        Int threads = 24
    }
    
    output {
        File last_reference_index = "*.lastdb"
        File last_reference_bck = "*.bck"
        File last_reference_des = "*.des"
        File last_reference_prj = "*.prj"
        File last_reference_sds = "*.sds"
        File last_reference_ssp = "*.ssp"
        File last_refernece_suf = "*.suf"
        File last_reference_tis = "*.tis"
    }

    String params = "-uRY32 -R01"
    String reference_fasta_name = basename(reference_fasta, ".fasta")

    Int disk_size = ceil(size(reference_fasta, "GB") * 1.5)

    command >>>
    
        source ~/.bashrc
        conda activate last
        echo "$(conda info)"
        echo "Generating last index of ~{reference_fasta} using params: ~{params}"

        (lastdb -P~{threads} ~{params} ~{reference_fasta_name}.lastdb ~{reference_fasta}) 2>&1
    
    <<<

    runtime {
        docker: "~{pb_conda_image}"
        preemptible: true
        maxRetries: 3
        cpu: "~{threads}"
        disk: ~{disk_size} + " GB"
    }

}

task last_align {
    input {
        String sample_name
        File last_reference_index
        File last_reference_bck
        File last_reference_des
        File last_reference_prj
        File last_reference_sds
        File last_reference_ssp
        File last_refernece_suf
        File last_reference_tis
        File haplotagged_bam 
        File haplotagged_bai
        File tg_bed 
        File score_matrix # need to get this file from PacBio
        Int threads = 24
    }

    output {
        File tg_maf = "~{sample_name}.maf.gz"
    }

    String extra = "-C2"
    
    String last_reference_name = basename(~{last_index}, ".lastdb")
    String score_matrix_name = basename(~{score_matrix}, ".par")
    
    command <<<
        source ~/.bashrc
        conda activate last
        echo "$(conda info)"
        
        echo "Outputting ~{tg_maf}."

       echo "Aligning ~{tg_bed} regions of ~{haplotagged_bam} to ~{last_reference_name} using lastal with ~{score_matrix_name} score matrix."

        (samtools view -@3 -bL ~{tg_bed} ~{haplotagged_bam} | samtools fasta \
         | lastal -P20 -p ~{score_matrix} ~{extra} ~{last_reference_index} - \
         | last-split | bgzip > ~{sample_name}.maf.gz) 2>&1
    >>>
    
    runtime {
        docker: "~{pb_conda_image}"
        preemptible: true
        maxRetries: 3
        cpu: "~{threads}"
        disk: "~{disk_size}" + " GB"
    }
}

task tandem_genotypes {
    input {
        File maf
        File tg_list_file
    }

    Int disk_size = ceil (size(maf, "GB") + size(tg_list_file, "GB") * 1.5)

    output {
        File sample_tandem_genotypes = "~{sample_name}.tandem-genotypes.txt"
    }
    
    command <<<
        source ~/.bashrc
        conda activate tandem_genotypes
        echo "$(conda info)"
        
        echo "Generating tandem repeate from ~{tg_list_file} regions in {maf} to ~{sample_tandem_genotypes}."

        tandem-genotypes ~{tg_list_file} ~{maf} > ~{sample_tandem_genotypes} 2>&1
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
        File sample_tandem_genotypes                        #f"samples/{sample}/tandem-genotypes/{sample}.tandem-genotypes.txt"
        String sample_name
    }

    output { 
        File sample_tandem_genotypes_absolute = ~{sample_name}.tandem-genotypes.absolute.txt                                #f"samples/{sample}/tandem-genotypes/{sample}.tandem-genotypes.absolute.txt"
    }

    Int disk_size = ceil(size(sample_tandem_genotypes, "GB") * 2)

    command <<<
              
        echo "Adjusting repeat count with reference counts for ~{sample_tandem_genotypes} to ~{sample_tandem_genotypes_absolute}."

        (awk -v OFS='\t' \
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
            }}' {sample_tandem_genotypes} > ~{sample_name}.tandem-genotypes.absolute.txt \
        ) 2>&1
        
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
        File sample_tandem_genotypes                                                                                      #f"samples/{sample}/tandem-genotypes/{sample}.tandem-genotypes.txt"
    }

    output {
        File tandem_genotypes_plot = ~{sample_name}.tandem-genotypes.pdf                                           #f"samples/{sample}/tandem-genotypes/{sample}.tandem-genotypes.pdf"
    }
    
    Int top_N_plots = 100
    Int disk_size = ceil(size(sample_tandem_genotypes, "GB") * 3)

    command <<<
        source ~/.bashrc
        conda activate tandem_genotypes
        echo "$(conda info)"
        
        echo "Plotting tandem repeat count for ~{sample_tandem_genotypes} to ~{tandem_genotypes_plot}."

        (tandem-genotypes-plot -n {top_N_plots} ~{sample_tandem_genotypes} ~{sample_name}.tandem-genotypes.pdf) 2>&1
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
        File haplotagged_bam                                                                                        #f"samples/{sample}/whatshap/{sample}.{ref}.deepvariant.haplotagged.bam",
        File haplotagged_bai                                                                                        #f"samples/{sample}/whatshap/{sample}.{ref}.deepvariant.haplotagged.bam.bai",
        File tg_bed
        String sample_name 
    }

    output {
        File tandem_genotypes_dropouts = "~{sample_name}.tandem-genotypes.dropouts.txt"
    }
    
    Int disk_size = ceil(size(haplotagged_bam, "GB") * 2)

    command <<<
        source ~/.bashrc
        conda activate tandem_genotypes
        echo "$(conda info)"

        echo "Identify coverage dropouts in ~{tg_bed} regions in ~{haplotagged_bam}."
        (python3 workflow/scripts/check_tandem_repeat_coverage.py ~{tg_bed} ~{haplotagged_bam} > ~{sample_name}.tandem-genotypes.dropouts.txt) > {log} 2>&1
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
    String sample_name
    Array[IndexedData] sample
    File? tg_list
    String? tg_list_url # optional- we don't want user downloading every time. Check for list- and download if necessary    
    IndexedData reference
    Array[String] regions
    String sample_name
    File score_matrix # need to get this file from PacBio
    File haplotagged_bam
    File haplotagged_bai
    String pb_conda_image
  }
 
  if (tg_list_url != null) {
    call download_tg_list{
        input:
            url = tg_list_url
    }
    tg_list = download_tg_list.tg_list_file
  }

  call generate_tg_bed {
    input:
        tg_list = tg_list,
        reference = reference,
        threads = 4
  }

  call generate_last_index {
    input:
        reference_fasta = reference.data,
        threads = 24
  }

  call last_align {
    input:
        sample_name = sample_name,
        last_reference_index = generate_last_index.last_reference_index,
        last_reference_bck = generate_last_index.last_reference_bck,
        last_reference_des = generate_last_index.last_reference_des,
        last_reference_prj = generate_last_index.last_reference_prj,
        last_reference_sds = generate_last_index.last_reference_sds,
        last_reference_ssp = generate_last_index.last_reference_ssp,
        last_refernece_suf = generate_last_index.last_refernece_suf,
        last_reference_tis = generate_last_index.last_reference_tis,
        haplotagged_bam = haplotagged_bam,
        haplotagged_bai = haplotagged_bai,
        tg_bed = generate_tg_bed.tg_bed,
        score_matrix = score_matrix,
        threads = 24
  }

    call tandem_genotypes {
        input:
            maf = last_align.tg_maf,
            tg_list_file = tg_list,
            sample_name = sample_name,
            score_matrix = score_matrix
    }

    call tandem_genotypes_absolute_count {
        input:
            sample_tandem_genotypes = tandem_genotypes.sample_tandem_genotypes,
            sample_name = sample_name
    }

    call tandem_genotypes_plot {
        input:
            sample_tandem_genotypes = tandem_genotypes_absolute_count.sample_tandem_genotypes_absolute
    }

    call tandem_repeat_coverage_dropouts {
        input:
            haplotagged_bam = haplotagged_bam,
            haplotagged_bai = haplotagged_bai,
            tg_bed = generate_tg_bed.tg_bed,
            sample_name = sample_name
    }

    output {
        File sample_tandem_genotypes = tandem_genotypes.sample_tandem_genotypes
        File sample_tandem_genotypes_absolute = tandem_genotypes_absolute_count.sample_tandem_genotypes_absolute
        File sample_tandem_genotypes_plot = tandem_genotypes_plot.tandem_genotypes_plot
        File sample_tandem_genotypes_dropouts = tandem_repeat_coverage_dropouts.tandem_genotypes_dropouts
    }

}