Delete from crc_md5;
Delete from suggestions_md5;

Drop PROCEDURE IF EXISTS evaluate;

Delimiter $$

CREATE PROCEDURE evaluate() 
BLOCK1: BEGIN 

	DECLARE no_more_rows1 			boolean DEFAULT FALSE; 
	DECLARE c_category_md5 			BINARY(16);
	DECLARE total_subjects_of_category 	INT; 
	DECLARE all_categories			INT;
	DECLARE	counter				INT;
	DECLARE accept_threshold		DECIMAL(2,2);
	DECLARE review_threshold		DECIMAL(2,2);


	DECLARE distinct_category_cursor CURSOR FOR 	SELECT DISTINCT category_md5 
							FROM cs_join_md5; 

	DECLARE total_subjects_cursor 	 CURSOR FOR 	SELECT COUNT(distinct subject_md5) 
							FROM cs_join_md5 
							WHERE category_md5 =c_category_md5; 

	DECLARE all_cat_cursor		 CURSOR FOR	SELECT COUNT(DISTINCT category_md5) from cs_join_md5;


	DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_rows1 = TRUE;
	

	OPEN 	all_cat_cursor;
	FETCH	all_cat_cursor INTO all_categories;	
	CLOSE	all_cat_cursor;
	SET 	counter = 0;


	OPEN distinct_category_cursor; 
	
	foreach_category_loop:LOOP 
		
		IF counter = all_categories THEN
			CLOSE distinct_category_cursor; 
			LEAVE foreach_category_loop; 
		END IF;
	
		
		SET counter = counter +1;


		IF no_more_rows1 THEN 
			CLOSE distinct_category_cursor; 
			LEAVE foreach_category_loop; 
		END IF; 



		FETCH	distinct_category_cursor INTO c_category_md5; 
		OPEN 	total_subjects_cursor; 
		FETCH 	total_subjects_cursor 	INTO total_subjects_of_category; 
		CLOSE 	total_subjects_cursor; 

		INSERT INTO crc_md5 VALUES(c_category_md5, total_subjects_of_category); 
		
		IF total_subjects_of_category < 3 THEN
			ITERATE foreach_category_loop;
		END IF;
		

		#variable thresholds
		IF total_subjects_of_category = 3 THEN
			SET accept_threshold	= 0.6;		
			SET review_threshold	= 0.3;
		ELSEIF total_subjects_of_category = 4 THEN
			SET accept_threshold	= 0.75;		
			SET review_threshold	= 0.5;
		ELSEIF total_subjects_of_category = 5 THEN
			SET accept_threshold	= 0.75;		
			SET review_threshold	= 0.5;
		ELSEIF total_subjects_of_category = 6 THEN
			SET accept_threshold	= 0.75;		
			SET review_threshold	= 0.5;
		ELSEIF total_subjects_of_category = 7 THEN
			SET accept_threshold	= 0.75;		
			SET review_threshold	= 0.5;
		ELSEIF total_subjects_of_category = 8 THEN
			SET accept_threshold	= 0.75;		
			SET review_threshold	= 0.5;
		ELSEIF total_subjects_of_category = 9 THEN
			SET accept_threshold	= 0.75;		
			SET review_threshold	= 0.5;
		ELSEIF total_subjects_of_category > 10 AND total_subjects_of_category < 20 THEN
			SET accept_threshold	= 0.75;		
			SET review_threshold	= 0.5;
		ELSEIF total_subjects_of_category > 20 THEN
			SET accept_threshold	= 0.75;		
			SET review_threshold	= 0.5;	
		END IF;


		BLOCK2: BEGIN 
			DECLARE no_more_rows2 		BOOLEAN DEFAULT FALSE; 
			DECLARE c_predicate_md5 	BINARY(16); 
			DECLARE c_object_md5 		BINARY(16); 
			#DECLARE probability 		FLOAT(2,2); 
			DECLARE probability 		DECIMAL(2,2);
			DECLARE concerned_subjects 	INT; 
			DECLARE dist_pred_obj_cursor CURSOR FOR SELECT DISTINCT predicate_md5, object_md5 
								FROM cs_join_md5 
								WHERE category_md5 = c_category_md5; 

			DECLARE concerned_subj_count CURSOR FOR SELECT COUNT(distinct subject_md5) 
								FROM cs_join_md5 
								WHERE category_md5	= c_category_md5 
								AND predicate_md5	= c_predicate_md5 
								AND object_md5		= c_object_md5; 

			DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_rows2=TRUE; 
			
			OPEN dist_pred_obj_cursor; 
			
			pred_obj_loop:LOOP 
				
				FETCH 	dist_pred_obj_cursor INTO c_predicate_md5, c_object_md5; 
				OPEN 	concerned_subj_count; 
				FETCH 	concerned_subj_count INTO concerned_subjects; 
				CLOSE 	concerned_subj_count; 
				
				SET probability = concerned_subjects / total_subjects_of_category; 

				IF no_more_rows2 THEN 
					CLOSE dist_pred_obj_cursor; 
					LEAVE pred_obj_loop; 
				END IF; 
				
				IF probability < review_threshold THEN
					ITERATE pred_obj_loop;
				END IF;


				BLOCK3: BEGIN 
					DECLARE no_more_rows3 	BOOLEAN DEFAULT FALSE; 
					DECLARE subject_wpo_md5 BINARY(16); 

					DECLARE suggestion_cursor CURSOR FOR 	SELECT DISTINCT(subject_md5) 
										FROM cs_join_md5 
										WHERE 	category_md5	= c_category_md5 
										AND 	predicate_md5 	!= c_predicate_md5 
										AND 	object_md5 	!= c_object_md5; 

					DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_rows3=TRUE; 
					

					OPEN suggestion_cursor; 
					

					get_suggestion_loop:LOOP

						FETCH suggestion_cursor INTO subject_wpo_md5; 
						IF probability > accept_threshold THEN 
							INSERT INTO suggestions_md5 VALUES('A', subject_wpo_md5, c_predicate_md5, c_object_md5, probability); 
						ELSEIF probability > review_threshold THEN 
							INSERT INTO suggestions_md5 VALUES ('R', subject_wpo_md5, c_predicate_md5, c_object_md5, probability); 
						END IF; 
						
						IF no_more_rows3 THEN 
							CLOSE suggestion_cursor; 
							LEAVE get_suggestion_loop; 
						END IF; 
					END LOOP get_suggestion_loop; 
				END BLOCK3; 
			END LOOP pred_obj_loop; 
		END BLOCK2; 
	END LOOP foreach_category_loop; 
END BLOCK1$$

Delimiter ;