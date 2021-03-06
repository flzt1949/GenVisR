################################################################################
##################### Public/Private Class Definitions #########################

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Public Class !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#

#' Class Lolliplot
#' 
#' An S4 class for the lolliplot object
#' @name Lolliplot-class
#' @rdname Lolliplot-class
#' @slot PlotA gtable object for the top sub-plot
#' @slot PlotB gtable object for the bottom sub-plot
#' @slot Grob gtable object storing the arranged plot
#' @slot primaryData data.table object storing the primary data
#' @slot geneData data.table object storing gene and domain coordinates
#' @exportClass Lolliplot
#' @import methods
#' @importFrom gtable gtable
#' @importFrom data.table data.table
methods::setOldClass("gtable")
setClass("Lolliplot",
         representation=representation(PlotA="gtable",
                                       PlotB="gtable",
                                       Grob="gtable",
                                       primaryData="data.table",
                                       geneData="data.table"),
         validity=function(object){
             
         })

#' Constructor for the Lolliplot class.
#' 
#' @name Lolliplot
#' @rdname Lolliplot-class
#' @param input Object of class MutationAnnotationFormat, GMS, VEP, or a data.table with appropriate columns
#' @param gene Character string specifying a gene to plot
#' @param transcript Character string specifying the ensembl transcript for which to plot, should be a transcript which corresponds
#' to the gene parameter.
#' @param species Character string specifying a species when using biomaRt queries
#' @param host Character string specifying a host to connect to when using biomaRt queries
#' @param txdb A bioconoductor txdb object to annotate amino acid positions, required only if amino acid changes are missing (see details).
#' @param BSgenome A bioconductor BSgenome object to annotate amino acid positions, required only if amino acid changes are missing (see details).
#' @export
Lolliplot <- function(input, gene, transcript=NULL, species="hsapiens", host="www.ensembl.org", txdb=NULL, BSgenome=NULL, verbose=FALSE){
    
    # Obtain and format the data
    data <- LolliplotData(input, gene=gene, transcript=transcript, species=species, host=host, txdb=txdb, BSgenome=BSgenome, verbose=verbose)
    
}

#!!!!!!!!!!!!!!!!!!!!!!!! Private Classes !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#

#' Private Class LolliplotData
#' 
#' An S4 class for the data of the Lolliplot object
#' @name LolliplotData-class
#' @rdname LolliplotData-class
#' @slot primaryData data.table object holding the primary data plotted
#' @slot geneData data.table object holding transcript and domain coordinates
#' @import methods
#' @importFrom data.table data.table
#' @noRd
setClass("LolliplotData",
         representation=representation(primaryData="data.table",
                                       geneData="data.table"),
         validity=function(object){
             
         })

#' Constructor for the LolliplotData class
#' 
#' @name LolliplotData
#' @rdname LolliplotData-class
#' @param object Object of class MutationAnnotationFormat, GMS, VEP, or a data.table with appropriate fields
#' @noRd
LolliplotData <- function(object, gene, transcript, species, host, txdb, BSgenome, verbose){
    
    # convert object to Lolliplot format
    lolliplotData <- toLolliplot(object, verbose=verbose)
    
    # filter the data by gene as a first step if no transcript is imediately available
    # this will reduce runtime by dramatically subsetting the data almost immediately
    lolliplotData <- filterByGene(lolliplotData, transcript=transcript, gene=gene, verbose=verbose)
    
    # annotate data with ensembl gene if necessary
    lolliplotData <- annotateGene(lolliplotData, species=species, host=host, verbose=verbose)
    
    # annotate data with ensembl transcripts if necessary
    lolliplotData <- annotateTranscript(lolliplotData, species=species, host=host, verbose=verbose)
    
    # grab the protien coordinates
    lolliplotData <- annotateProteinCoord(lolliplotData, species=species, host=host, txdb=txdb, BSgenome=BSgenome, verbose=verbose)
    
    # filter data to only one transcript
    lolliplotData <- filterByTranscript(lolliplotData, transcript, verbose)
    
    # tabulate the frequency of observed mutations
    lolliplotData <- calcMutFreq(lolliplotData, verbose)
    
    # get the transcript size and domains
    proteinData <- constructTranscriptData(lolliplotData, species=species, host=host, verbose)
        
    # set the initial mutation heights (tier 1)
    lolliplotData <- setTierOne(lolliplotData, verbose)
    
    # set the mutations for the second tier
    
    browser()
}

#' PrivateClass LolliplotPlots
#' 
#' An S4 class for the grobs of the Lolliplot object
#' @name LolliplotPlots-class
#' @rdname LolliplotPlots-class
#' @slot PlotA gtable object for the top plot.
#' @slot PlotB gtable object for the bottom plot.
#' @import methods
#' @importFrom gtable gtable
#' @noRd
setClass("LolliplotPlots", 
         representation=representation(PlotA="gtable",
                                       PlotB="gtable"),
         validity=function(object){
             
         })

#' Constructor for the LolliplotPlots class
#' 
#' @name LolliplotPlots
#' @rdname LolliplotPlots-class
#' @param object Object of class LolliplotData
#' @noRd
LolliplotPlots <- function(object, verbose){
    
}

################################################################################
########################### Accessor function definitions ######################

################################################################################
########################### Method function definitions ########################

#' @rdname filterByGene-methods
#' @aliases filterByGene
#' @param object Object of class data.table
#' @param gene Character string specifying a gene name
#' @param verbose Boolean specifying if status messages should be reported
#' @noRd
setMethod(f="filterByGene",
          signature="data.table",
          definition=function(object, gene, verbose, ...){
              
              # print status message
              if(verbose){
                  memo <- paste("Filtering data by the gene:", toString(gene))
                  message(memo)
              }
              
              # perform quality checks to the parameter gene
              if(!is.character(gene)){
                  memo <- paste("argument supplied to the parameter gene is not",
                                "a character vector... attempting to coerce")
                  gene <- as.character(gene)
                  warning(memo)
              }
              if(length(gene) != 1){
                  memo <- paste("argument supplied to the parameter gene has a",
                                "length greater than 1... using only the first element")
                  gene <- gene[1]
                  warning(memo)
              }
              
              # check that the gene to filter is in the data
              if(!any(object$gene %in% gene)){
                  memo <- paste("The string given to the parameter gene does not",
                                "exist in the data!")
                  stop(memo)
              }
              
              # perform the filtering and refactor the column
              index <- object$gene %in% gene
              object <- object[index,]
              object$gene <- factor(object$gene, levels=unique(object$gene))
              
              return(object)
          })

#' @rdname annotateTranscript-methods
#' @aliases annotateTranscript
#' @param object Object of class data.table
#' @param verbose Boolean specifying if status messages should be reported
#' @importFrom biomaRt useMart
#' @importFrom biomaRt listDatasets
#' @importFrom biomaRt useDataset
#' @importFrom biomaRt getBM
#' @noRd
setMethod(f="annotateTranscript",
          signature="data.table",
          definition=function(object, species, host, verbose, ...){
              
              # first check if a transcript column exists
              if("transcript" %in% colnames(object)){
                  
                  # next check to see if they appear to be ensembl transcripts
                  if(any(grepl("ENST00", object$transcript))){
                      
                      if(verbose){
                          memo <- paste("Found a transcript column with ensembl transcript annotations",
                                        "skipping transcript annotation")
                          message(memo)
                      }
                      object$ensembl_transcript_id <- object$transcript
                      return(object)
                  }
              }
              
              # annotate the transcripts using the gene
              if(verbose){
                  memo <- paste("Annotating ensembl transcripts via biomaRt")
              }
              
              # load the appropriate mart
              ensembl_mart <- biomaRt::useMart("ENSEMBL_MART_ENSEMBL",
                                               host=host)
              
              # select proper data set given regexp print warnings if unexpected out occur
              dataset <- biomaRt::listDatasets(ensembl_mart)$dataset
              index <- which(grepl(species, dataset))
              if(length(index)>1)
              {
                  memo <- paste(toString(species), " Matches more than one dataset for the",
                                 " ensembl mart, please specify a species in the, ",
                                 "following format: hsapiens")
                  stop(memo)
              } else if(length(index)==0) {
                  memo <- paste(toString(species), " does not appear to be supported by biomaRt",
                                 "if you beleive this to be in error please modify", 
                                 "you're input to to conform to this format: hsapiens")
                  stop(memo)
              }
              
              ensembl_mart <- biomaRt::useDataset(as.character(dataset[index]),
                                                  mart=ensembl_mart)
             
              # Apply various filters using vector of values
              # biomaRt::listFilters(ensembl_mart)
              filters <- c("ensembl_gene_id")
              values <- c(as.character(object$ensembl_gene_id))
              
              # Select attributes to retrieve (protein domain, start, stop)
              # biomaRt::listAttributes(ensembl_mart)
              attributes <- c("ensembl_gene_id", "ensembl_transcript_id")
              
              # Retrieve data
              result <- biomaRt::getBM(attributes=attributes, filters=filters,
                                       values=values, mart=ensembl_mart)
              
              # add in the data and print a status message for what happened
              nrowOrig <- nrow(object)
              object <- merge(object, result, by=c("ensembl_gene_id"), allow.cartesian=TRUE)
              
              if(verbose){
                  memo <- paste("biomaRt found", toString(length(result$ensembl_transcript_id)),
                                "ensembl transcripts for gene id", toString(unique(result$ensembl_gene_id)),
                                ", expanding", nrowOrig, "entries to", nrow(object))
              }
              
              # reorder columns for consistency
              keep <- c("sample", "chromosome", "start", "stop", "refAllele",
                        "varAllele", "gene", "consequence", "ensembl_gene_id",
                        "ensembl_transcript_id")
              object <- object[,keep, with=FALSE]
              
              return(object)
          })

#' @rdname annotateGene-methods
#' @aliases annotateGene
#' @param object Object of class data.table
#' @param verbose Boolean specifying if status messages should be reported
#' @importFrom biomaRt useMart
#' @importFrom biomaRt listDatasets
#' @importFrom biomaRt useDataset
#' @importFrom biomaRt getBM
#' @noRd
setMethod(f="annotateGene",
          signature="data.table",
          definition=function(object, species, host, verbose, ...){
              
              # next check to see if they appear to be ensembl transcripts
              if(all(grepl("ENSG00", object$gene))){
                  
                  if(verbose){
                      memo <- paste("Found a gene column with ensembl gene annotations",
                                    "skipping gene annotation")
                      message(memo)
                  }
                  object$ensembl_gene_id <- object$gene
                  return(object)
              }

              # annotate the gene using the gene
              if(verbose){
                  memo <- paste("Annotating ensembl genes via biomaRt")
              }
              
              # load the appropriate mart
              ensembl_mart <- biomaRt::useMart("ENSEMBL_MART_ENSEMBL",
                                               host=host)
              
              # select proper data set given regexp print warnings if unexpected out occur
              dataset <- biomaRt::listDatasets(ensembl_mart)$dataset
              index <- which(grepl(species, dataset))
              if(length(index)>1)
              {
                  memo <- paste(toString(species), " Matches more than one dataset for the",
                                " ensembl mart, please specify a species in the, ",
                                "following format: hsapiens")
                  stop(memo)
              } else if(length(index)==0) {
                  memo <- paste(toString(species), " does not appear to be supported by biomaRt",
                                "if you beleive this to be in error please modify", 
                                "you're input to to conform to this format: hsapiens")
                  stop(memo)
              }
              
              ensembl_mart <- biomaRt::useDataset(as.character(dataset[index]),
                                                  mart=ensembl_mart)
              
              # Apply various filters using vector of values
              # biomaRt::listFilters(ensembl_mart)
              filters <- c("hgnc_symbol")
              values <- c(as.character(object$gene))
              
              # Select attributes to retrieve (protein domain, start, stop)
              # biomaRt::listAttributes(ensembl_mart)
              attributes <- c("ensembl_gene_id")
              
              # Retrieve data
              result <- biomaRt::getBM(attributes=attributes, filters=filters,
                                       values=values, mart=ensembl_mart)
              
              # add in the data and return the structure
              object$ensembl_gene_id <- result
              
              return(object)
          })

#' @rdname annotateProteinCoord-methods
#' @aliases annotateProteinCoord
#' @param object Object of class data.table
#' @param verbose Boolean specifying if status messages should be reported
#' @importFrom VariantAnnotation predictCoding
#' @importFrom Biostrings DNAStringSet
#' @importFrom biomaRt useMart
#' @importFrom biomaRt listDatasets
#' @importFrom biomaRt useDataset
#' @importFrom biomaRt getBM
#' @noRd
setMethod(f="annotateProteinCoord",
          signature="data.table",
          definition=function(object, species, host, txdb, BSgenome, verbose, ...){
              
              ##################################################################
              ############ if AA_change column is present ######################
              
              # first look for an amino acid column, if it's present get the
              # protein coordinates from there and do quality checks
              if(any(colnames(object) %in% "AA_change")){
                  if(all(is.numeric(object$AA_change))){
                      
                      object$AA_coord <- object$AA_change
                      return(object)
                      
                  } else if(all(grepl("^p\\.", object$AA_change))){
                      
                      if(verbose){
                          memo <- paste("p. notation detected in AA_change column,",
                                        "converting to numeric values")
                          message(memo)
                      }
                      
                      object$AA_coord <- as.numeric(gsub("p\\.[*a-zA-z]*(\\d+).*?$",
                                                         "\\1", object$AA_change,
                                                         perl=TRUE))
                      return(object)
                  } else {
                      if(verbose){
                          memo <- paste("Failed to extract protein coordinates",
                                        "attempting to annotate these using txdb object!")
                          message(memo)
                      }
                  }

              }
              
              ##################################################################
              ############ if AA_change column is not present ##################
              
              # check that required objects are present
              if(is.null(txdb) || is.null(BSgenome)){
                  memo <- paste("A valid txdb and BSgenome object are required when GenVisR must annotate",
                                "protein coordinates, but found null for these parameters.")
                  stop(memo)
              }
              
              # annotate the mutation coordinates given on the transcript level
              if(verbose){
                  memo <- paste("Attempting to annotate protein coordinates.")
              }

              # make sure BSgenome object matches txdb object
              seqBSgenome <- VariantAnnotation::seqlevels(BSgenome)
              seqtxdb <- VariantAnnotation::seqlevels(txdb)
              
              if(!all(seqBSgenome %in% seqtxdb) || !all(seqtxdb %in% seqBSgenome)){
                  mismatchSeqBSgenome <- seqBSgenome[!seqBSgenome %in% seqtxdb]
                  mismatchSeqtxdb <- seqtxdb[!seqtxdb %in% seqBSgenome]
                  mismatchSeq <- unique(c(mismatchSeqBSgenome, mismatchSeqtxdb))
                  
                  memo <- paste("The following entires are not in both the txdb and BSgenome objects supplied:",
                                toString(mismatchSeq), "This may affect protien annotations if mutations are in these regions!")
                  warning(memo)
              }
              
              # make sure lolliplotData matches the BSgenome and txdb object
              chrMismatch <- as.character(unique(object[!object$chromosome %in% seqtxdb,]$chromosome))
              
              if(length(chrMismatch) >= 1){
                  
                  memo <- paste("The following chromosomes do not match the supplied BSgenome object",
                                toString(chrMismatch))
                  warning(memo)
                  
                  # test if the chr mismatch is fixed by appending chr to chromosomes
                  chrMismatch_appendChr <- sum(as.character(unique(paste0("chr", object$chromosome))) %in% seqBSgenome)
                  if(chrMismatch_appendChr <= length(chrMismatch)){
                      memo <- paste("appending \"chr\" to chromosomes in attempt to fix mismatch with the BSgenome")
                      warning(memo)
                      object$chromosome <- paste0("chr", object$chromosome)
                  }
              }
              
              # convert data to a GRanges object
              gr1 <- GRanges(seqnames=object$chromosome, ranges=IRanges(start=object$start, end=object$stop), strand="*", mcols=object[,c("ensembl_gene_id", "sample", "refAllele", "varAllele", "gene", "consequence", "ensembl_transcript_id")])
              
              # get the protein coordinates
              gr1 <- VariantAnnotation::predictCoding(gr1, txdb, BSgenome, Biostrings::DNAStringSet(object$varAllele))
              gr1 <- data.table::as.data.table(gr1)
              
              # add in the TXNAME for the TXID from gr1
              txnameDT <- unique(data.table::as.data.table(select(txdb, gr1$TXID, "TXNAME", keytype="TXID")))
              txnameDT$TXID <- as.character(txnameDT$TXID)
              gr1$TXID <- as.character(gr1$TXID)
              object <- merge(gr1, txnameDT, by=c("TXID"))
              
              # choose columns to keep
              keep <- c("mcols.sample", "seqnames", "start", "end", "mcols.refAllele", "mcols.varAllele",
                        "mcols.gene", "mcols.consequence", "mcols.ensembl_gene_id", "mcols.ensembl_transcript_id",
                        "PROTEINLOC", "TXNAME", "REFCODON", "VARCODON", "REFAA", "VARAA")
              object <- object[,keep,with=FALSE]
              colnames(object) <- c("sample", "chromosome", "start", "stop", "refAllele", "varAllele", "gene",
                                    "consequence", "ensembl_gene_id", "ensembl_transcript_id", "txdb.proteinCoord",
                                    "txdb.transcript", "txdb.refCodon", "txdb.varCodon", "txdb.refAA", "txdb.varAA")
              object$proteinCoord <- object$txdb.proteinCoord
              
              # load the appropriate mart
              ensembl_mart <- biomaRt::useMart("ENSEMBL_MART_ENSEMBL",
                                               host=host)
              
              # select proper data set given regexp print warnings if unexpected out occur
              dataset <- biomaRt::listDatasets(ensembl_mart)$dataset
              index <- which(grepl(species, dataset))
              if(length(index)>1)
              {
                  memo <- paste(toString(species), " Matches more than one dataset for the",
                                " ensembl mart, please specify a species in the, ",
                                "following format: hsapiens")
                  stop(memo)
              } else if(length(index)==0) {
                  memo <- paste(toString(species), " does not appear to be supported by biomaRt",
                                "if you beleive this to be in error please modify", 
                                "you're input to to conform to this format: hsapiens")
                  stop(memo)
              }
              
              ensembl_mart <- biomaRt::useDataset(as.character(dataset[index]),
                                                  mart=ensembl_mart)
              
              # Apply various filters using vector of values
              # biomaRt::listFilters(ensembl_mart)
              filters <- c("ucsc")
              values <- c(object$txdb.transcript)
              
              # Select attributes to retrieve (protein domain, start, stop)
              # biomaRt::listAttributes(ensembl_mart)
              attributes <- c("ensembl_transcript_id", "ucsc")
              
              # Retrieve data
              result <- biomaRt::getBM(attributes=attributes, filters=filters,
                                       values=values, mart=ensembl_mart)
              
              if(length(unique(result$ensembl_transcript_id)) != length(unique(result$ucsc))){
                  memo <- paste("Retrieved protein coordinates are for the transcript", toString(unique(result$ucsc)),
                  "However GenVisR uses ensemble transcript id's", "there is not a 1 to 1 mapping between the two,",
                  "annotated coordinates may be inaccurate!")
                  warning(memo)
              }
              
              # use the biomaRt results to subset to only valid ensembl transcripts
              object <- object[object$ensembl_transcript_id %in% result$ensembl_transcript_id,]
              
              return(object)
          })

#' @rdname filterByTranscript-methods
#' @aliases filterByTranscript
#' @param object Object of class data.table
#' @param verbose Boolean specifying if status messages should be reported
#' @noRd
setMethod(f="filterByTranscript",
          signature="data.table",
          definition=function(object, transcript, verbose, ...){
              
              # status message
              if(verbose){
                  memo <- paste("Filtering data by transcript")
                  message(memo)
              }
              
              # pick a transcript to filter on if none is given
              if(is.null(transcript)){
                  transcript <- unique(object$ensembl_transcript_id)[1]
                  if(verbose){
                      memo <- paste("parameter transcript is null, using transcript",
                                    toString(transcript), "available transcripts were:",
                                    toString(unique(object$ensembl_transcript_id)))
                      message(memo)
                  }
              }
              
              # perform quality checks
              if(!is.character(transcript)){
                  memo <- paste("input to transcript is not a character vector, attempting to coerce")
                  warning(memo)
              }
              if(length(transcript) > 1){
                  memo <- paste("input to transcript is not of length 1, using only the first element:", toString(transcript[1]))
                  warning(memo)
              }
              
              # check that the transcript is in the data
              if(!transcript %in% object$ensembl_transcript_id){
                  transcriptTmp <- unique(object$ensembl_transcript_id)[1]
                  memo <- paste("Did not find the specified transcript:", toString(transcript),
                                "in the data. Using:", toString(transcriptTmp), "instead!")
                  warning(memo)
                  transcript <- transcriptTmp
              }
              
              # subset the data.table
              object <- object[object$ensembl_transcript_id == transcript,]
              
              return(object)
          })

#' @rdname calcMutFreq-methods
#' @aliases calcMutFreq
#' @param object Object of class data.table
#' @param verbose Boolean specifying if status messages should be reported
#' @importFrom plyr count
#' @noRd
setMethod(f="calcMutFreq",
          signature="data.table",
          definition=function(object, verbose, ...){
              
              # print status message
              if(verbose){
                  memo <- paste("Calculating the frequency of mutations")
                  message(memo)
              }
              
              # make a temporary key making each mutation type unique, at this 
              # stage there should only be one transcript making genomic locations unique
              object$key <- paste(object$chromosome, object$start, object$stop, object$refAllele, object$varAllele, sep=":")
              
              # tabulate the frequencies
              mutationFreq <- plyr::count(object$key)
              colnames(mutationFreq) <- c("key", "mutationFreq")
              object <- merge(object, mutationFreq, by="key", all.x=TRUE)
              
              # remove the key column and return the object
              object$key <- NULL
              
              return(object)
          })

#' @rdname constructTranscriptData-methods
#' @aliases constructTranscriptData
#' @param object Object of class data.table
#' @param verbose Boolean specifying if status messages should be reported
#' @importFrom plyr count
#' @noRd
setMethod(f="constructTranscriptData",
          signature="data.table",
          definition=function(object, species, host, verbose, ...){
              
              # make sure there's only one transcript
              if(length(unique(object$ensembl_transcript_id)) != 1){
                  memo <- paste("Number of transcripts does not equal one",
                                "unable to retrieve domains")
                  stop(memo)
              }
              
              # set the transcript
              transcript <- unique(object$ensembl_transcript_id)
              
              # print status message
              if(verbose){
                  memo <- paste("Retrieving protein domains for:", toString(transcript))
                  message(memo)
              }
              
              # Load in mart
              ensembl_mart <- biomaRt::useMart("ENSEMBL_MART_ENSEMBL",
                                               host=host)
              
              # select proper data set given regexp print warnings if unexpected out occur
              dataset <- biomaRt::listDatasets(ensembl_mart)$dataset
              index <- which(grepl(species, dataset))
              if(length(index)>1)
              {
                  memo <- paste0(species, " Matches more than one dataset for the",
                                 " ensembl mart, please specify a species in the, ",
                                 "following format: hsapiens")
                  stop(memo)
              } else if(length(index)==0) {
                  memo <- paste0(species, " does not appear to be supported by biomaRt",
                                 "if you beleive this to be in error please modify", 
                                 "you're input to to conform to this format: hsapiens")
                  stop(memo)
              }
              ensembl_mart <- biomaRt::useDataset(as.character(dataset[index]),
                                                  mart=ensembl_mart)
              
              ############ Retrieve Domains ####################################
              
              # Apply various filters using vector of values
              #biomaRt::listFilters()
              filters <- c("ensembl_transcript_id")
              values <- as.list(c(transcript))
              
              # Select attributes to retrieve (protein domain, start, stop)
              #biomaRt::listAttributes()
              attributes <- c("interpro_description",
                              "interpro_short_description",
                              "interpro_start",
                              "interpro_end")
              
              # Retrieve data
              domain <- biomaRt::getBM(attributes=attributes, filters=filters,
                                       values=values, mart=ensembl_mart)
              domain <- as.data.table(domain)
              colnames(domain) <- c("interproDesc", "interproShortDesc", "proteinStart", "proteinStop")
              
              # check that domains were actually retrieved
              if(nrow(domain) < 1){
                  
                  if(verbose){
                      memo <- paste("biomaRt did not return protein domains")
                      message(memo)
                  }
                  
              } else {
                  domain$source <- "domain" 
              }
              
              
              ################ Retrieve transcript size ########################
              
              
              # Apply various filters using vector of values
              # biomaRt::listFilters()
              filters <- c("ensembl_transcript_id")
              values <- as.list(c(transcript))
              
              # Select attributes to retrieve (protein domain, start, stop)
              # biomaRt::listAttributes()
              attributes <- c("cds_length")
              
              # Retrieve data
              protein <- biomaRt::getBM(attributes=attributes, filters=filters,
                                        values=values, mart=ensembl_mart)
              protein <- as.data.table(protein)
              colnames(protein) <- "proteinStop"
              
              # make sure we have a protein length otherwise theres no gene to plot
              if(nrow(protein) < 1){
                  memo <- paste("biomaRt failed to return a CDS length for transcript:", toString(transcript))
                  warning(memo)
              } else {
                  protein$proteinStart <- 1
                  protein$source <- "protein"
                  protein$proteinStop <- protein$proteinStop/3
              }

              proteinData <- data.table::rbindlist(list(protein, domain), use.names=TRUE, fill=TRUE)
              
              return(proteinData)

          })

#' @rdname setTierOne-methods
#' @aliases setTierOne
#' @param object Object of class data.table
#' @param verbose Boolean specifying if status messages should be reported
#' @noRd
setMethod(f="setTierOne",
          signature="data.table",
          definition=function(object, verbose, ...){
              
              # status message
              if(verbose){
                  memo <- paste("setting coordinates for first tier of mutations")
                  message(memo)
              }
              
              # set a base height
              object$height <- 1.2
              
              if(min(object$mutationFreq) != max(object$mutationFreq)){
                  # adjust the height of points based on their frequency as a scaling factor
                  a <- function(x){(x-min(x))/(max(x)-min(x))}
                  object$height <- object$height + a(object$mutationFreq)
              }
              
              # return the object with adjusted heights
              return(object)
          })
