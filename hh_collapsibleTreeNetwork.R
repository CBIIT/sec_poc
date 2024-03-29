#' Create Network Interactive Collapsible Tree Diagrams
#'
#' Interactive Reingold-Tilford tree diagram created using D3.js,
#' where every node can be expanded and collapsed by clicking on it.
#' This function serves as a convenience wrapper for network style data frames
#' containing the node's parent in the first column, node parent in the second
#' column, and additional attributes in the rest of the columns. The root node
#' is denoted by having an \code{NA} for a parent. There must be exactly 1 root.
#'
#' @param df a network data frame (where every row is a node)
#' from which to construct a nested list
#' \itemize{
#'  \item First column must be the parent (\code{NA} for root node)
#'  \item Second column must be the child
#'  \item Additional columns are passed on as attributes for other parameters
#'  \item There must be exactly 1 root node
#' }
#' @param inputId the input slot that will be used to access the selected node (for Shiny).
#' Will return a named list of the most recently clicked node,
#' along with all of its parents.
#' (For \code{collapsibleTreeNetwork} the names of the list are tree depth)
#' @param attribute numeric column not listed in hierarchy that will be used
#' as weighting to define the color gradient across nodes. Defaults to 'leafCount',
#' which colors nodes by the cumulative count of its children
#' @param aggFun aggregation function applied to the attribute column to determine
#' values of parent nodes. Defaults to \code{sum}, but \code{mean} also makes sense.
#' @param fill either a single color or a column name with the color for each node
#' @param linkLength length of the horizontal links that connect nodes in pixels.
#' (optional, defaults to automatic sizing)
#' @param fontSize font size of the label text in pixels
#' @param tooltip tooltip shows the node's label and attribute value.
#' @param tooltipHtml column name (possibly containing html) to override
#' default tooltip contents, allowing for more advanced customization
#' @param nodeSize numeric column that will be used to determine relative node size.
#' Default is to have a constant node size throughout. 'leafCount' can also
#' be used here (cumulative count of a node's children), or 'count'
#' (count of node's immediate children).
#' @param collapsed the tree's children will start collapsed by default.
#' Can also be a logical value found in the data for conditionally collapsing nodes.
#' @param zoomable pan and zoom by dragging and scrolling
#' @param width width in pixels (optional, defaults to automatic sizing)
#' @param height height in pixels (optional, defaults to automatic sizing)
#'
#' @examples
#' # Create a simple org chart
#' org <- data.frame(
#'   Manager = c(
#'     NA, "Ana", "Ana", "Bill", "Bill", "Bill", "Claudette", "Claudette", "Danny",
#'     "Fred", "Fred", "Grace", "Larry", "Larry", "Nicholas", "Nicholas"
#'   ),
#'   Employee = c(
#'     "Ana", "Bill", "Larry", "Claudette", "Danny", "Erika", "Fred", "Grace",
#'     "Henri", "Ida", "Joaquin", "Kate", "Mindy", "Nicholas", "Odette", "Peter"
#'   ),
#'   Title = c(
#'     "President", "VP Operations", "VP Finance", "Director", "Director", "Scientist",
#'     "Manager", "Manager", "Jr Scientist", "Operator", "Operator", "Associate",
#'      "Analyst", "Director", "Accountant", "Accountant"
#'   )
#' )
#' collapsibleTreeNetwork(org, attribute = "Title")
#'
#' # Add in colors and sizes
#' org$Color <- org$Title
#' levels(org$Color) <- colorspace::rainbow_hcl(11)
#' collapsibleTreeNetwork(
#'   org,
#'   attribute = "Title",
#'   fill = "Color",
#'   nodeSize = "leafCount",
#'   collapsed = FALSE
#' )
#'
#' # Use unsplash api to add in random photos to tooltip
#' org$tooltip <- paste0(
#'   org$Employee,
#'   "<br>Title: ",
#'   org$Title,
#'   "<br><img src='https://source.unsplash.com/collection/385548/150x100'>"
#' )
#'
#' collapsibleTreeNetwork(
#'   org,
#'   attribute = "Title",
#'   fill = "Color",
#'   nodeSize = "leafCount",
#'   tooltipHtml = "tooltip",
#'   collapsed = FALSE
#' )
#'
#' @source Christopher Gandrud: \url{http://christophergandrud.github.io/networkD3/}.
#' @source d3noob: \url{https://bl.ocks.org/d3noob/43a860bc0024792f8803bba8ca0d5ecd}.
#' @seealso \code{\link[data.tree]{FromDataFrameNetwork}} for underlying function
#' that constructs trees from the network data frame
#'
#' @import htmlwidgets
#' @importFrom data.tree ToListExplicit FromDataFrameNetwork
#' @importFrom data.tree Traverse Do Aggregate
#' @export
hh_collapsibleTreeNetwork <- function(df, inputId = NULL, attribute = "leafCount",
                                      aggFun = sum, fill = "lightsteelblue",
                                      linkLength = NULL, fontSize = 10, tooltip = TRUE,
                                      tooltipHtml = NULL, nodeSize = NULL, collapsed = TRUE,
                                      zoomable = TRUE, width = NULL, height = NULL) {
  
  # acceptable inherent node attributes
  nodeAttr <- c("leafCount", "count")
  
  #stop("Hubert's code")
  # reject bad inputs
  print(paste('colnames are ', colnames(df)))
  if(!is.data.frame(df)) stop("df must be a data frame")
  if(sum(is.na(df[,1])) != 1) stop("there must be 1 NA for root in the first column")
  if(!is.character(fill)) stop("fill must be a either a color or column name")
  if(!(attribute %in% c(colnames(df), nodeAttr))) stop("attribute column name is incorrect")
  if(is.character(collapsed) & !(collapsed %in% c(colnames(df), nodeAttr))) stop("collapsed column name is incorrect")
  if(!is.null(tooltipHtml)) if(!(tooltipHtml %in% colnames(df))) stop("tooltipHtml column name is incorrect")
  if(!is.null(nodeSize)) if(!(nodeSize %in% c(colnames(df), nodeAttr))) stop("nodeSize column name is incorrect")
  
  # root is the node with NA as a parent
  root <- df[is.na(df[,1]),]
  tree <- df[!is.na(df[,1]),]
  # browser()
  # convert the data frame network into a data.tree node
  if (nrow(df)==1) {
    # Special case of single node tree
    root[1,1] <- "Fake"
    node <- data.tree::FromDataFrameNetwork(root)
    node <- node$children[[1]]
    collapsed <- FALSE
  } else {
    # Normal tree
    node <- data.tree::FromDataFrameNetwork(tree)
  }
  print(paste(Sys.time(), "created nodes FromDataFrameNetwork"))
  # apply root attributes from df to the node (data.tree doesn't automatically do this)
  rootAttr <- root[-(1:2)]
  Map(function(value, name) node[[name]] <- value, rootAttr, names(rootAttr))
  print(paste(Sys.time(), "Fixed root attributes"))
  
  print(paste(Sys.time(), "starting margin calcs"))
  # calculate the right and left margins in pixels
  #browser()
  leftMargin <- nchar(node$name)
  # rightLabelVector <- node$Get("name", filterFun = function(x) x$level==node$height)
  # required for single node trees
  #  if (is.null(rightLabelVector)) rightLabelVector <- ""
  # rightMargin <- max(sapply(rightLabelVector, nchar))
  rightMargin <- 80
  print(paste(Sys.time(), "margin calcs complete"))
  #browser()
  # create a list that contains the options
  options <- list(
    hierarchy = 1:node$height,
    input = inputId,
    attribute = attribute,
    linkLength = linkLength,
    fontSize = fontSize,
    tooltipHtml = tooltipHtml,
    tooltip = tooltip,
    collapsed = collapsed,
    zoomable = TRUE,
    margin = list(
      top = 20,
      bottom = 20,
      left = (leftMargin * fontSize/2) + 25,
      right = (rightMargin * fontSize/2) + 25
    )
  )
  
  # these are the fields that will ultimately end up in the json
  jsonFields <- NULL
  
  print(paste(Sys.time(), 'Setting fills'))
  if(fill %in% colnames(df)) {
    # fill in node colors based on column name
    node$Do(function(x) x$fill <- x[[fill]])
    jsonFields <- c(jsonFields, "fill")
  } else {
    # default to using fill value as literal color name
    options$fill <- 'red'
    # options[['stroke-width']] <- 0
  }
  print(paste(Sys.time(), 'Done with  fills'))
  #browser()
  #only necessary to perform these calculations if there is a tooltip
  #if(tooltip & is.null(tooltipHtml)) {
  if(tooltip) {
    if (is.numeric(df[[attribute]]) & substitute(aggFun)!="identity") {
      # traverse down the tree and compute the weights of each node for the tooltip
      t <- data.tree::Traverse(node, "pre-order")
      data.tree::Do(t, function(x) {
        x$WeightOfNode <- data.tree::Aggregate(x, attribute, aggFun)
        # make the tooltips look nice
        x$WeightOfNode <- prettyNum(
          x$WeightOfNode, big.mark = ",", digits = 3, scientific = FALSE
        )
      })
    } else {
      # Can't perform an aggregation on non-numeric
      node$Do(function(x) x$WeightOfNode <- x[[attribute]])
    }
    jsonFields <- c(jsonFields, "WeightOfNode")
  }
  #browser()
  # if tooltipHtml is specified, pass it on in the data
  if(tooltip & !is.null(tooltipHtml)) {
    node$Do(function(x) x$tooltip <- x[[tooltipHtml]])
    jsonFields <- c(jsonFields, "tooltip")
  }
  
  # if collapsed is specified, pass it on in the data
  if(is.character(collapsed)) jsonFields <- c(jsonFields, collapsed)
  
  # only necessary to perform these calculations if there is a nodeSize specified
  if(!is.null(nodeSize)) {
    print("have a nodeSize")
    # Scale factor to keep the median leaf size around 10
    #scaleFactor <- 10/data.tree::Aggregate(node, nodeSize, stats::median)
    # traverse down the tree and compute the weights of each node for the tooltip
    t <- data.tree::Traverse(node, "pre-order")
    # can't use substitute inside a subfunction
    aggFunIsIdentity <- substitute(aggFun)=="identity"
    #browser()
    data.tree::Do(t, function(x) {
      x$SizeOfNode <- x[[nodeSize]]
      #  else x$SizeOfNode <- data.tree::Aggregate(x, nodeSize, sum)
      # scale node growth to area rather than radius and round
      # x$SizeOfNode <- round(sqrt(x$SizeOfNode*scaleFactor)*pi, 2)
    })
    # update left margin based on new root size
    options$margin$left <- options$margin$left + node$SizeOfNode - 10
    jsonFields <- c(jsonFields, "SizeOfNode")
  }
  
  # keep only the JSON fields that are necessary
  if(is.null(jsonFields)) jsonFields <- NA
  data <- data.tree::ToListExplicit(node, unname = TRUE, keepOnly = jsonFields)
  
  # pass the data and options using 'x'
  x <- list(
    data = data,
    options = options
  )
  
  print("ready to create widget")
  # create the widget
  htmlwidgets::createWidget(
    "collapsibleTree_htest", x, width = width, height = height,
    htmlwidgets::sizingPolicy(viewer.padding = 0)
  )
}
