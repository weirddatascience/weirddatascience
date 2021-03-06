library( tidyverse )
library( tidyselect )
library( magrittr )

library( rstan )
library( bayesplot )

library( shinystan )

library( ggplot2 )

library( tidytext )


# Load Tirant data
message( "Reading raw Tirant data..." )
tirant_tbl <- 
	read_csv( "data/tirant_raw.csv", col_names=FALSE ) %>%
	rename( chapter = X1, text = X2 ) %>%
	mutate( page = as.numeric( rownames(.) ) )

# Tokenize
tirant_words <-
	tirant_tbl %>%
	unnest_tokens( word, text ) 

# Pivot the data wider to be presented to Stan as a matrix of multinomial samples.
tirant_lengths <-
	tirant_words %>% 
	mutate( word_length = str_length( word ) ) %>%
	mutate( word_length = ifelse( word_length > 9, 10, word_length )) %>%
	group_by( page, word_length ) %>%
	summarise( count = n( )) %>%
	pivot_wider( names_from = word_length, values_from = count ) %>%
	ungroup %>%
	select( -c(page,"5","6","7","8","9","10") ) %>%
	select(sort(peek_vars())) %>%
	replace( is.na(.), 0 )

if( not( file.exists( "work/multinomial_changepoint_tirant_fit.rds" ) ) ) {

	message( "Fitting multinomial model.")
	tirant_multinom_fit <-
		stan( "multinomial_changepoint.stan", 
			  data=list( 
							num_obs=487, 
							num_cats=4,
							y = as.matrix( tirant_lengths ),
							alpha = rep( 1, 4 ) ),
			  iter=16000,
				control=list( 
								 adapt_delta=0.98,
								 max_treedepth=15 ) )

	saveRDS( tirant_multinom_fit, "work/multinomial_changepoint_tirant_fit.rds" )

} else {
	message( "Loading saved multinomial model.")
	tirant_multinom_fit <- readRDS( "work/multinomial_changepoint_tirant_fit.rds" )
}

# Plot the calculated changepoint probabilities.
# ('changepoint_simplex').
mean_changepoint_prob <-
	extract( tirant_multinom_fit )$changepoint_simplex %>% 
	as_tibble( .name_repair="unique" ) %>%
	summarise_all( mean ) %>% 
	pivot_longer( everything() ) %>% 
	rowid_to_column() 

# Save values for plotting
saveRDS( mean_changepoint_prob, file="work/mean_changepoint_prob_tirant.rds" )

