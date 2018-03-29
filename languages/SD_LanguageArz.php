<?php
/**
 * @ingroup Language
 * @ingroup SDLanguage
 * @author Meno25
 */

class SD_LanguageArz extends SD_Language {
	/* private */ var $m_SpecialProperties = [
		// always start upper-case
		// category properties
		SD_SP_HAS_FILTER  => 'لديه فلتر',
		SD_SP_HAS_DRILLDOWN_TITLE  => 'لديه عنوان دريل داون',
		// filter properties
		SD_SP_COVERS_PROPERTY  => 'يغطى الخاصية',
		SD_SP_GETS_VALUES_FROM_CATEGORY => 'يحصل على القيم من التصنيف',
		SD_SP_REQUIRES_FILTER => 'يتطلب الفلتر',
		SD_SP_HAS_LABEL  => 'لديه العلامة',
		// English stuff, to avoid crashes
		SD_SP_HAS_DISPLAY_PARAMETERS => 'Has display parameters',
	];

	var $m_Namespaces = [
		SD_NS_FILTER		=> 'فلتر',
		SD_NS_FILTER_TALK	=> 'نقاش_الفلتر'
	];
}
