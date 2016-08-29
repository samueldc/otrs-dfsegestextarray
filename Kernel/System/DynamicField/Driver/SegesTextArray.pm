# --
# Kernel/System/DynamicField/Driver/SegesTextArray.pm - based on existing OTRS-Backends - Delegate for DynamicField SegesTextArray backend
# Copyright (C) 2016 samueldc, http://www.camara.leg.br
#
# written/edited by:
# * nedmaj(at)yahoo(dot)com
#
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::SegesTextArray;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use Data::Dumper;

use base qw(Kernel::System::DynamicField::Driver::BaseSegesTextArray);

our @ObjectDependencies = (
    'Kernel::System::DynamicFieldValue',
);

=head1 NAME

Kernel::System::DynamicField::Driver::SegesTextArray

=head1 SYNOPSIS

DynamicFields SegesTextArray backend delegate

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Backend>.
Please look there for a detailed reference of the functions.

=over 4

=item new()

usually, you want to create an instance of this
by using Kernel::System::DynamicField::Backend->new();

=cut

sub ValueGet {
    my ( $Self, %Param ) = @_;

    my $DFValue = $Kernel::OM->Get('Kernel::System::DynamicFieldValue')->ValueGet(
        FieldID  => $Param{DynamicFieldConfig}->{ID},
        ObjectID => $Param{ObjectID},
    );

    return if !$DFValue;
    return if !IsArrayRefWithData($DFValue);
    return if !IsHashRefWithData( $DFValue->[0] );

    # extract real values
    my @ReturnData;
    for my $Item ( @{$DFValue} ) {
        push @ReturnData, $Item->{ValueText};
    }

    return \@ReturnData;
}

sub ValueSet {
    my ( $Self, %Param ) = @_;

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

	$Kernel::OM->Get('Kernel::System::Log')->Log(
	    Priority => 'error',
	    Message  => Dumper(\@Values),
	);

    my @ValueText;
    if ( IsArrayRefWithData( \@Values ) ) {
        for my $Item (@Values) {
            push @ValueText, { ValueText => $Item };
        }
    }
    else {
        push @ValueText, { ValueText => '' };
    }

	$Kernel::OM->Get('Kernel::System::Log')->Log(
	    Priority => 'error',
	    Message  => Dumper(\@ValueText),
	);

    my $Success = $Kernel::OM->Get('Kernel::System::DynamicFieldValue')->ValueSet(
        FieldID  => $Param{DynamicFieldConfig}->{ID},
        ObjectID => $Param{ObjectID},
        Value    => \@ValueText,
        UserID   => $Param{UserID},
    );

    return $Success;
}

sub ValueValidate {
    my ( $Self, %Param ) = @_;
    my $Success;

    # check value
    my @Values;
    if ( IsArrayRefWithData( $Param{Value} ) ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    for my $Item (@Values) {

        $Success = $Kernel::OM->Get('Kernel::System::DynamicFieldValue')->ValueValidate(
            Value => {
                ValueText => $Item,
            },
            UserID => $Param{UserID}
        );
        return if !$Success
    }
    return $Success;
}

sub EditFieldRender {
    my ( $Self, %Param ) = @_;

    # take config from field config
    my $FieldConfig = $Param{DynamicFieldConfig}->{Config};
    my $FieldID     = $Param{DynamicFieldConfig}->{ID};
    my $FieldName   = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    my $Value = [];

    $Value = $Param{Value} if defined $Param{Value};

    # extract the dynamic field value form the web request
    my $FieldValue = $Self->EditFieldValueGet(
        %Param,
    );

    # set values from ParamObject if present
    if ( IsArrayRefWithData($FieldValue) ) {
        $Value = $FieldValue;
    }

    # check and set class if necessary
    my $FieldClass = 'DynamicFieldText';
    if ( defined $Param{Class} && $Param{Class} ne '' ) {
        $FieldClass .= ' ' . $Param{Class};
    }

    # set field as mandatory
    $FieldClass .= ' Validate_Required' if $Param{Mandatory};

    # set error css class
    $FieldClass .= ' ServerError' if $Param{ServerError};

    my $ArrayElements = scalar( @{$Value} );
    my $MaxArraySize = $FieldConfig->{MaxArraySize} || 5;

    # store field HTML
    my $HTMLString = '';

    my $SelectionData;

    for my $Count ( 1 .. $ArrayElements ) {

        $HTMLString .= <<"EOF";
<div style="margin-bottom:2px;">
EOF

        my $FieldNameCount = $FieldName . '_' . $Count;

		my $DisplayValue = $Self->ValueLookup( %Param, Key => $Value->[ $Count - 1 ] );
		my $DisplayTitle = $DisplayValue;
		my $DisplayValueHTML = $Param{LayoutObject}->Ascii2Html(
			Text => $DisplayValue,
		);
		my $DisplayTitleHTML = $Param{LayoutObject}->Ascii2Html(
			Text => $DisplayTitle,
		);
		my $DisplayFieldName      = $FieldName . 'Display';
		my $DisplayFieldNameCount = $DisplayFieldName . '_' . $Count;

		$HTMLString .= <<"EOF";
<input type="text" class="$FieldClass" id="$DisplayFieldNameCount" name="$DisplayFieldName" title="$DisplayTitleHTML" value="$DisplayValueHTML" style="width: 50%" />
<input type="hidden" id="$FieldNameCount" name="$FieldName" value="$Value->[$Count-1]" />
<button type="button" id="Remove_$FieldNameCount" class="Remove ValueRemove" value="Remove value">\$Text{"Remove value"}</button>
</div>
EOF

        $Param{LayoutObject}->AddJSOnDocumentComplete( Code => <<"EOF");
//bind click function to remove button
\$('#Remove_$FieldNameCount').bind('click', function () {
  \$('#$DisplayFieldNameCount').val('');
  \$('#$DisplayFieldNameCount').attr("title", '');
  \$('#$FieldNameCount').val('');
  \$('#$FieldNameCount').data('DisplayValue', '');
  \$('#$FieldNameCount').data('DisplayTitle', '');
  \$('#$FieldNameCount').attr('disabled', true).parent().addClass('Hidden').insertBefore(\$('#Add_$FieldName').parent());
  if ( \$("[name='$FieldName']:enabled").length < $MaxArraySize ) {
    \$('#Add_$FieldName').parent().removeClass('Hidden');
  }
  \$('#$FieldNameCount').trigger('change');
  return false;
});
//bind change function to display field
\$('#$DisplayFieldNameCount').bind('change', function () {
  \$('#$FieldNameCount').val(\$('#$DisplayFieldNameCount').val());
  return false;
});
EOF


    }

    for my $Count ( ( $ArrayElements + 1 ) .. $MaxArraySize ) {

        $HTMLString .= <<"EOF";
<div style="margin-bottom:2px;">
EOF

        my $FieldNameCount = $FieldName . '_' . $Count;

		my $DisplayFieldName      = $FieldName . 'Display';
		my $DisplayFieldNameCount = $DisplayFieldName . '_' . $Count;

		$HTMLString .= <<"EOF";
<input type="text" class="$FieldClass" id="$DisplayFieldNameCount" name="$DisplayFieldName" title="" value="" style="width: 50%" />
<input type="hidden" id="$FieldNameCount" name="$FieldName" value="" />
<button type="button" id="Remove_$FieldNameCount" class="Remove ValueRemove" value="Remove value">\$Text{"Remove value"}</button>
</div>
EOF

		 $Param{LayoutObject}->AddJSOnDocumentComplete( Code => <<"EOF");
//bind click function to remove button
\$('#Remove_$FieldNameCount').bind('click', function () {
  \$('#$DisplayFieldNameCount').val('');
  \$('#$DisplayFieldNameCount').attr("title", '');
  \$('#$FieldNameCount').val('');
  \$('#$FieldNameCount').data('DisplayValue', '');
  \$('#$FieldNameCount').data('DisplayTitle', '');
  \$('#$FieldNameCount').attr('disabled', true).parent().addClass('Hidden').insertBefore(\$('#Add_$FieldName').parent());
  if ( \$("[name='$FieldName']:enabled").length < $MaxArraySize ) {
    \$('#Add_$FieldName').parent().removeClass('Hidden');
  }
  \$('#$FieldNameCount').trigger('change');
  return false;
});
\$('#$FieldNameCount').attr('disabled', true).parent().addClass('Hidden');
//bind change function to display field
\$('#$DisplayFieldNameCount').bind('change', function () {
  \$('#$FieldNameCount').val(\$('#$DisplayFieldNameCount').val());
  return false;
});
EOF

    }

    my $ClassHidden = '';
    if ( $ArrayElements >= $MaxArraySize ) {
        $ClassHidden = 'Hidden';
    }
    $HTMLString .= <<"EOF";
<div class="$ClassHidden">
<button id="Add_$FieldName" class="Add" type="button" value="Add value">\$Text{"Add value"}</button>
</div>
EOF

$Param{LayoutObject}->AddJSOnDocumentComplete( Code => <<"EOF");
//bind click function to add button
\$('#Add_$FieldName').bind('click', function () {
    \$("[name='$FieldName']:disabled").first().attr('disabled', false).parent().removeClass('Hidden');
    if ( \$("[name='$FieldName']:enabled").length >= $MaxArraySize ) {
        \$('#Add_$FieldName').parent().addClass('Hidden');
    }
    return false;
});
EOF

    if ( $Param{Mandatory} ) {

        # for client side validation
        my $DivID = $FieldName . 'Error';

        my $FieldRequiredMessage
            = $Param{LayoutObject}->{LanguageObject}->Translate("This field is required.");

        # for client side validation
        $HTMLString .= <<"EOF";

    <div id="$DivID" class="TooltipErrorMessage">
        <p>
            $FieldRequiredMessage
        </p>
    </div>
EOF
    }

    if ( $Param{ServerError} ) {

        my $ErrorMessage = $Param{ErrorMessage} || 'This field is required.';
        $ErrorMessage = $Param{LayoutObject}->{LanguageObject}->Translate($ErrorMessage);

        my $DivID = $FieldName . 'ServerError';

        # for server side validation
        $HTMLString .= <<"EOF";
    <div id="$DivID" class="TooltipErrorMessage">
        <p>
            $ErrorMessage
        </p>
    </div>
EOF
    }

    # call EditLabelRender on the common backend
    my $LabelString = $Self->EditLabelRender(
        %Param,
        Mandatory          => $Param{Mandatory} || '0',
        FieldName          => $FieldName,
    );

    my $Data = {
        Field => $HTMLString,
        Label => $LabelString,
    };

    return $Data;
}

sub EditFieldValueGet {
    my ( $Self, %Param ) = @_;

    my $FieldName = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    my $Value;

    # check if there is a Template and retreive the dynamic field value from there
    if ( IsHashRefWithData( $Param{Template} ) ) {
        $Value = $Param{Template}->{$FieldName};
    }

    # otherwise get dynamic field value form param
    else {
        my @Data = $Param{ParamObject}->GetArray( Param => $FieldName );
        $Value = \@Data;
    }

    if ( defined $Param{ReturnTemplateStructure} && $Param{ReturnTemplateStructure} eq '1' ) {
        return {
            $FieldName => $Value,
        };
    }

    # for this field the normal return an the ReturnValueStructure are the same
    return $Value;
}

sub EditFieldValueValidate {
    my ( $Self, %Param ) = @_;

    # get the field value from the http request
    my $Value = $Self->EditFieldValueGet(
        DynamicFieldConfig => $Param{DynamicFieldConfig},
        ParamObject        => $Param{ParamObject},

        # not necessary for this backend but place it for consistency reasons
        ReturnValueStructure => 1,
    );

    my $ServerError;
    my $ErrorMessage;

    # perform necessary validations
    if ( $Param{Mandatory} && !IsArrayRefWithData($Value) ) {
        return {
            ServerError => 1,
        };
    }

    # create resulting structure
    my $Result = {
        ServerError  => $ServerError,
        ErrorMessage => $ErrorMessage,
    };

    return $Result;
}

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set HTMLOuput as default if not specified
    if ( !defined $Param{HTMLOutput} ) {
        $Param{HTMLOutput} = 1;
    }

    # get raw Value strings from field value
    my @Keys;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Keys = @{ $Param{Value} };
    }
    else {
        @Keys = ( $Param{Values} );
    }

    my @Values;

    for my $Key (@Keys) {

        $Key ||= '';

        my $Value = $Self->ValueLookup( %Param, Key => $Key, );

        # set title as value after update and before limit
        my $Title = $Value;

        # HTMLOuput transformations
        if ( $Param{HTMLOutput} ) {
            $Value = $Param{LayoutObject}->Ascii2Html(
                Text => $Value,
                Max => $Param{ValueMaxChars} || '',
            );

            $Title = $Param{LayoutObject}->Ascii2Html(
                Text => $Title,
                Max => $Param{TitleMaxChars} || '',
            );
            # set field link form config
            my $HasLink = 0;
            my $OldValue;
        }
        else {
            if ( $Param{ValueMaxChars} && length($Value) > $Param{ValueMaxChars} ) {
                $Value = substr( $Value, 0, $Param{ValueMaxChars} ) . '...';
            }
            if ( $Param{TitleMaxChars} && length($Title) > $Param{TitleMaxChars} ) {
                $Title = substr( $Title, 0, $Param{TitleMaxChars} ) . '...';
            }
        }
        push @Values, $Value;
    }

    # set item separator
    my $ItemSeparator = $Param{DynamicFieldConfig}->{Config}->{ItemSeparator} || ', ';

    my $Value = join( $ItemSeparator, @Values );

    my $Data = {
        Value => $Value,
        Title => '',
        Link  => '',
    };

    return $Data;
}

sub ReadableValueRender {
    my ( $Self, %Param ) = @_;

    # set Value and Title variables
    my $Value = '';
    my $Title = '';

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    my @ReadableValues;

    VALUEITEM:
    for my $Item (@Values) {
        next VALUEITEM if !$Item;

        push @ReadableValues, $Item;
    }

    # set item separator
    my $ItemSeparator = $Param{DynamicFieldConfig}->{Config}->{ItemSeparator} || ', ';

    # Ouput transformations
    $Value = join( $ItemSeparator, @ReadableValues );
    $Title = $Value;

    # cut strings if needed
    if ( $Param{ValueMaxChars} && length($Value) > $Param{ValueMaxChars} ) {
        $Value = substr( $Value, 0, $Param{ValueMaxChars} ) . '...';
    }
    if ( $Param{TitleMaxChars} && length($Title) > $Param{TitleMaxChars} ) {
        $Title = substr( $Title, 0, $Param{TitleMaxChars} ) . '...';
    }

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title,
    };

    return $Data;
}

sub TemplateValueTypeGet {
    my ( $Self, %Param ) = @_;

    my $FieldName = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    # set the field types
    my $EditValueType   = 'ARRAY';
    my $SearchValueType = 'ARRAY';

    # return the correct structure
    if ( $Param{FieldType} eq 'Edit' ) {
        return {
            $FieldName => $EditValueType,
            }
    }
    elsif ( $Param{FieldType} eq 'Search' ) {
        return {
            'Search_' . $FieldName => $SearchValueType,
            }
    }
    else {
        return {
            $FieldName             => $EditValueType,
            'Search_' . $FieldName => $SearchValueType,
            }
    }
}

sub ObjectMatch {
    my ( $Self, %Param ) = @_;

    my $FieldName = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};

    # return false if field is not defined
    return 0 if ( !defined $Param{ObjectAttributes}->{$FieldName} );

    # the attribute must be an array
    return 0 if !IsArrayRefWithData( $Param{ObjectAttributes}->{$FieldName} );

    my $Match;

    # search in all values for this attribute
    VALUE:
    for my $AttributeValue ( @{ $Param{ObjectAttributes}->{$FieldName} } ) {

        next VALUE if !defined $AttributeValue;

        # only need to match one
        if ( $Param{Value} eq $AttributeValue ) {
            $Match = 1;
            last VALUE;
        }
    }
    return $Match;
}

sub PossibleValuesGet {
    my ( $Self, %Param ) = @_;

    return;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut
