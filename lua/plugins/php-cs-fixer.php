<?php

// Fallback for files without a project-specific PHP CS Fixer configuration.
return (new PhpCsFixer\Config())->setRules(['@PSR12' => true]);
