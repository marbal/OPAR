package OTRS::OPR::Web::App::Forms;

use strict;
use warnings;
use Captcha::reCAPTCHA;
use Digest::MD5 qw(md5_hex);

use parent 'OTRS::OPR::Exporter::Aliased';

our @EXPORT_OK = qw(check_formid get_formid validate_captcha validate_formid);

sub validate_formid {
    my ($self, $params) = @_;
    
    my $success = $self->check_formid( $params->{formid} );
    
    if ( !$success ) {
        $self->notify({
            type    => 'error',
            include => 'notifications/generic_error',
            ERROR_HEADLINE => 'The form ID was invalid',
            ERROR_MESSAGE  => 'The form ID was invalid',
        });
        
        return;
    }
    
    return 1;
}

sub validate_captcha {
    my ($self, $params, $opts) = @_;
    
    my $captcha = Captcha::reCAPTCHA->new;
    my $result  = $captcha->check_answer(
        $self->config->get( 'recaptcha.private_key' ),
        $ENV{REMOTE_ADDR},
        $params->{recaptcha_challenge_field},
        $params->{recaptcha_response_field},
    );
    
    if ( !$result->{is_valid} ) {
        
        # show registration form again with error message
        $self->notify({
            type           => 'error',
            include        => 'notifications/generic_error',
            ERROR_HEADLINE => 'Captcha wrong!',
            ERROR_MESSAGE  => 'Your solution of the captcha was wrong!',
        });
        
        return;
    }
    
    return 1;
}

sub check_formid {
    my ($self,$id) = @_;
    
    _delete_expired( $self );
    
    my $already_used;
    
    my ($object) = $self->table( 'opr_formid' )->find( $id );
    
    if ( $object ) {
        $already_used = $object->used;
        $object->used( 1 );
        $object->update;
    }
    
    return $object && !$already_used;
}

sub get_formid {
    my ($self, $expiration_span) = @_;
    
    my $formid = md5_hex( time . ( $ENV{REMOTE_ADDR} || '127.0.0.1' ) . rand 1000 );
    my $expire = time + ( $expiration_span || $self->config->get( 'formid.expire' ) );
    
    my ($object) = $self->table( 'opr_formid' )->create( {
        formid => $formid,
        expire => $expire,
        used   => 0,
    } );
    
    $object->in_storage ? $object->update : $object->insert;
    
    return $object->formid;
}

sub _delete_expired {
    my ($self) = @_;
    
    $self->table( 'opr_formid' )->search({
        expire => { '<' => time },
    })->delete;
    
    return 1;
}

1;