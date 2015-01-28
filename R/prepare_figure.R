prepare_figure <- function(fig) {
  legend <- list()

  ## resolve aesthetic mappings
  for(ly in fig$layers) {
    if(!is.null(ly$maps)) {
      for(nm in names(ly$maps)) {
        mapItem <- ly$maps[[nm]]
        if(is.numeric(mapItem$domain)) {
          intervals <- pretty(mapItem$domain, 6)
          nl <- length(intervals) - 1
          mapItem$domain <- intervals
          mapItem$labels <- levels(cut(mapItem$domain, intervals, include.lowest = TRUE))
          mapItem$values <- (head(intervals, nl) + tail(intervals, nl)) / 2
        } else {
          mapItem$labels <- mapItem$domain
          mapItem$values <- mapItem$domain
        }
        ## map the glyphs attributes
        for(entry in mapItem$mapEntries) {
          did <- fig$model[[entry$id]]$attributes$data_source$id
          for(attr in entry$mapArgs) {
            ## handle glyph type
            if(attr == "glyph") {
              gl <- fig$model[[entry$id]]$attributes$glyph
              newType <- underscore2camel(getThemeValue(underscore2camel(mapItem$domain), gl$type, attr))
              ## should check things in resolveGlyphProps() with new glyph
              fig$model[[entry$id]]$attributes$glyph$type <- newType
              fig$model[[gl$id]]$type <- newType
            } else {
              curDat <- fig$model[[did]]$attributes$data[[attr]]
              fig$model[[did]]$attributes$data[[attr]] <- getThemeValue(mapItem$domain, curDat, attr)
            }
          }
        }

        ## add legend glyphs and build legend element
        for(ii in seq_along(mapItem$labels)) {
          curVal <- mapItem$values[[ii]]
          curLab <- mapItem$labels[[ii]]
          lgndId <- paste(nm, curLab, sep = "_")
          legend[[lgndId]] <- list(list(curLab, list()))

          for(glph in mapItem$legendGlyphs) {
            for(mrg in glph$mapArgs)
              glph$args[[mrg]] <- getThemeValue(mapItem$domain, curVal, mrg)
            # render legend glyph
            spec <- c(glph$args, list(x = "x", y = "y"))
            lgroup <- paste("legend_", nm, "_", curLab, sep = "")
            lname <- glph$args$glyph
            glrId <- genId(fig, c("glyphRenderer", lgroup, lname))
            fig <- fig %>% addLayer(spec = spec, dat = data.frame(x = c(NA, NA), y = c(NA, NA)), lname = lname, lgroup = lgroup)

            # add reference to glyph to legend object
            nn <- length(legend[[lgndId]][[1]][[2]]) + 1
            legend[[lgndId]][[1]][[2]][[nn]] <- list(type = "GlyphRenderer", id = glrId)
          }
        }
      }
    }
  }

  ## deal with common legend, if any
  if(length(fig$commonLegend) > 0) {
    for(lg in fig$commonLegend) {
      lgroup <- paste("common_legend", lg$name, sep = "_")
      legend[[lgroup]] <- list(list(lg$name, list()))
      for(lgArgs in lg$args) {
        spec <- c(lgArgs, list(x = "x", y = "y"))
        lname <- lgArgs$glyph
        glrId <- genId(fig, c("glyphRenderer", lgroup, lname))
        fig <- fig %>% addLayer(spec = spec, dat = data.frame(x = c(NA, NA), y = c(NA, NA)), lname = lname, lgroup = lgroup)

        # add reference to glyph to legend object
        nn <- length(legend[[lgroup]][[1]][[2]]) + 1
        legend[[lgroup]][[1]][[2]][[nn]] <- list(type = "GlyphRenderer", id = glrId)
      }
    }
  }

  if(length(legend) > 0)
    fig <- fig %>% addLegend(unname(unlist(legend, recursive = FALSE)))

  ## see if there is a log axis so we can compute padding appropriately
  ## log axis is only available if explicitly specified through x_axis()
  ## or y_axis(), so at this point, *_mapper_type should be defined
  xLog <- yLog <- FALSE
  if(!is.null(fig$model$plot$attributes$x_mapper_type))
    xLog <- TRUE
  if(!is.null(fig$model$plot$attributes$y_mapper_type))
    yLog <- TRUE

  ## set xlim and ylim if not set
  if(length(fig$xlim) == 0) {
    message("xlim not specified explicitly... calculating...")
    xrange <- getAllGlyphRange(fig$glyphXRanges, fig$padding_factor, fig$xAxisType, xLog)
  } else {
    xrange <- fig$xlim
  }

  if(length(fig$ylim) == 0) {
    message("ylim not specified explicitly... calculating...")
    yrange <- getAllGlyphRange(fig$glyphYRanges, fig$padding_factor, fig$yAxisType, yLog)
  } else {
    yrange <- fig$ylim
  }

  fig <- fig %>%
    x_range(xrange) %>%
    y_range(yrange)

  if(!fig$hasXaxis) {
    if(is.null(fig$xlab)) {
      fig <- fig %>% x_axis("x", grid = fig$xgrid, position = fig$xaxes)
    } else {
      fig <- fig %>% x_axis(fig$xlab, grid = fig$xgrid, position = fig$xaxes)
    }
  }

  if(!fig$hasYaxis) {
    if(is.null(fig$ylab)) {
      fig <- fig %>% y_axis("y", grid = fig$ygrid, position = fig$yaxes)
    } else {
      fig <- fig %>% y_axis(fig$ylab, grid = fig$ygrid, position = fig$yaxes)
    }
  }

  ## see if we need to execute any deferred functions
  if(length(fig$glyphDefer) > 0) {
    for(dfr in fig$glyphDefer) {
      tmpSpec <- dfr$fn(dfr$spec, xrange, yrange)
      tmpData <- dfr$fn(dfr$data, xrange, yrange)
      fig <- fig %>% addLayer(tmpSpec, tmpData, dfr$lname, dfr$lgroup)
    }
  }

  fig
}