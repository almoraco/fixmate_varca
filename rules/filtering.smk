def get_vartype_arg(wildcards):
    return "--select-type-to-include {}".format(
        "SNP" if wildcards.vartype == "snvs" else "INDEL")


rule select_calls:
    input:
        ref=config["ref"]["genome"],
        vcf=f"{OUTDIR}/genotyped/{{group}}.vcf.gz"
    output:
        vcf=temp(f"{OUTDIR}/filtered/{{group}}.{{vartype}}.vcf.gz")
    params:
        extra=get_vartype_arg,
        java_opts="-XX:ParallelGCThreads={}".format(get_resource("select_calls","threads"))
    log:
        f"{LOGDIR}/gatk/selectvariants/{{group}}.{{vartype}}.log"
    resources:
        mem_mb = get_resource("select_calls","mem_mb"),
        runtime = get_resource("select_calls","runtime")
    benchmark:
        f"{LOGDIR}/benchmarks/{{group}}.{{vartype}}.select_calls.txt"
    wrapper:
        "v3.5.0/bio/gatk/selectvariants"


def get_filter(wildcards):
    return {
        "snv-hard-filter":
        config["filtering"]["hard"][wildcards.vartype]}


rule recalibrate_calls:
    input:
        vcf=f"{OUTDIR}/filtered/{{group}}.{{vartype}}.vcf.gz",
        ref=config["ref"]["genome"],
        hapmap=config["params"]["gatk"]["VariantRecalibrator"]["hapmap"],
        omni=config["params"]["gatk"]["VariantRecalibrator"]["omni"],
        g1k=config["params"]["gatk"]["VariantRecalibrator"]["g1k"],
        dbsnp=config["params"]["gatk"]["VariantRecalibrator"]["dbsnp"],
        aux=config["params"]["gatk"]["VariantRecalibrator"]["aux"]
    output:
        vcf=f"{OUTDIR}/filtered/{{group}}.{{vartype}}.recalibrated.vcf.gz",
        tranches=f"{OUTDIR}/filtered/{{group}}.{{vartype}}.tranches"
    params:
        mode=lambda wc: "SNP"
                if wc.vartype == "snvs"
                else "INDEL",
        resources=config["params"]["gatk"]["VariantRecalibrator"]["parameters"],
        annotation=config["params"]["gatk"]["VariantRecalibrator"]["annotation"],
        extra=config["params"]["gatk"]["VariantRecalibrator"]["extra"],
        java_opts="-XX:ParallelGCThreads={}".format(get_resource("recalibrate_calls","threads"))
    log:
        f"{LOGDIR}/gatk/variantrecalibrator/{{group}}.{{vartype}}.log"
    resources:
        mem_mb = get_resource("recalibrate_calls","mem_mb"),
        runtime = get_resource("recalibrate_calls","runtime")
    benchmark:
        f"{LOGDIR}/benchmarks/{{group}}.{{vartype}}.recalibrate_calls.txt"
    wrapper:
        "v3.5.0/bio/gatk/variantrecalibrator"

# esto es lo que hay que entregar
rule merge_calls:
    input:
        vcfs=lambda wc: expand(f"{OUTDIR}/filtered/{wc.group}.{{vartype}}.vcf.gz",
                   vartype=["snvs", "indels"])
    output:
        vcf=f"{OUTDIR}/filtered/{{group}}.vcf.gz"
    params:
        extra = "",
        java_opts = "-XX:ParallelGCThreads={}".format(get_resource("merge_calls","threads"))
    log:
        f"{LOGDIR}/picard/{{group}}.merge-filtered.log"
    resources:
        mem_mb = get_resource("merge_calls","mem_mb"),
        runtime = get_resource("merge_calls","runtime")
    benchmark:
        f"{LOGDIR}/benchmarks/{{group}}.merge_calls.txt"
    wrapper:
        "v3.5.0/bio/picard/mergevcfs"

# filtros de contaminación et al.
rule learn_read_orientation_model:
    input:
        f1r2=f"{OUTDIR}/mutect/{{sample}}.f1r2.tar.gz"
    output:
        rom=f"{OUTDIR}/mutect/{{sample}}_read_orientation_model.tar.gz"
    log:
        f"{LOGDIR}/gatk/read_orientation_model.{{sample}}.log"
    params:
        extra="",
        java_opts="-XX:ParallelGCThreads={}".format(get_resource("learn_read_orientation_model", "threads"))
    resources:
        mem_mb = get_resource("learn_read_orientation_model","mem_mb"),
        runtime = get_resource("learn_read_orientation_model","runtime")
    benchmark:
        f"{LOGDIR}/benchmarks/{{sample}}.learn_read_orientation_model.txt"
    wrapper:
        "v3.5.0/bio/gatk/learnreadorientationmodel"

rule filter_mutect_calls:
    input:
        vcf=f"{OUTDIR}/mutect/{{sample}}.vcf.gz",
        ref=config["ref"]["genome"],
        f1r2=f"{OUTDIR}/mutect/{{sample}}_read_orientation_model.tar.gz" if config["filtering"]["mutect"]["lrom"] else []
    output:
        vcf=f"{OUTDIR}/mutect_filter/{{sample}}_passlabel.vcf.gz"
    params:
        extra=config["params"]["gatk"]["mutect"],
        java_opts="-XX:ParallelGCThreads={}".format(get_resource("filter_mutect_calls", "threads"))
    log:
        f"{LOGDIR}/gatk/mutect_filter.{{sample}}.log"
    resources:
        mem_mb = get_resource("filter_mutect_calls","mem_mb"),
        runtime = get_resource("filter_mutect_calls","runtime")
    benchmark:
        f"{LOGDIR}/benchmarks/{{sample}}.filter_mutect_calls.txt"
    wrapper:
        "v3.5.0/bio/gatk/filtermutectcalls"

# esto es lo que hay que entregar
rule filter_mutect_2:
    input:
        vcf=f"{OUTDIR}/mutect_filter/{{sample}}_passlabel.vcf.gz",
        ref=config["ref"]["genome"]
    output:
        vcf=f"{OUTDIR}/mutect_filter/{{sample}}_passlabel_filtered.vcf.gz"
    params:
        filters={"DPfilter": config["filtering"]["mutect"]["depth"]},
        java_opts="-XX:ParallelGCThreads={}".format(get_resource("filter_mutect_2","threads"))
    log:
        f"{LOGDIR}/gatk/variantfiltration/{{sample}}_mutect.log"
    resources:
        mem_mb = get_resource("filter_mutect_2","mem_mb"),
        runtime = get_resource("filter_mutect_2","runtime")
    benchmark:
        f"{LOGDIR}/benchmarks/{{sample}}.filter_mutect_2.txt"
    wrapper:
        "v3.5.0/bio/gatk/variantfiltration"
